import Foundation
import SwiftData
import Testing
@testable import MoneyLog

@MainActor
// Tests for the repositories, run against a fresh in-memory database.
//
// These check the rules that protect the data: you can't delete an account that
// has history, a category has to match the transaction type, deleting a goal
// takes its contributions with it, and running the repeat engine twice doesn't
// create the same transaction twice.
@Suite("Repositories")
struct RepositoryTests {
    // MARK: Seeding

    @Test func seedingIsIdempotent() throws {
        let store = try TestStore()
        let categoryCount = try store.context.fetchCount(FetchDescriptor<TransactionCategory>())
        #expect(categoryCount == SeedDataService.expenseSeeds.count + SeedDataService.incomeSeeds.count)
        #expect(try SeedDataService(context: store.context, currency: .inr).seedIfNeeded() == false)
        #expect(try store.context.fetchCount(FetchDescriptor<TransactionCategory>()) == categoryCount)
        #expect(try store.app.accounts.accounts(includeArchived: false).count == 1)
    }

    // MARK: Transactions

    @Test func createTransactionUpdatesBalanceAndRecency() throws {
        let store = try TestStore()
        let cash = try store.cash()
        let food = try store.expenseCategory()

        try store.app.transactions.create(TransactionDraft(
            amount: .inr(250), type: .expense, accountID: cash.id, categoryID: food.id, merchant: "  Swiggy  "
        ))

        #expect(try store.app.accounts.balance(of: cash) == .inr(-250))
        #expect(try store.app.accounts.balances()[cash.id] == .inr(-250))
        #expect(food.usageCount == 1)
        #expect(try store.app.categories.recentlyUsed(of: .expense, limit: 3).first?.id == food.id)
        #expect(try store.app.transactions.recentMerchants(limit: 5) == ["Swiggy"])
    }

    @Test func rejectsMismatchedCategoryType() throws {
        let store = try TestStore()
        let draft = TransactionDraft(amount: .inr(10), type: .expense, accountID: try store.cash().id, categoryID: try store.incomeCategory().id)
        #expect(throws: AppError.validation(.categoryTypeMismatch)) { try store.app.transactions.create(draft) }
        #expect(try store.context.fetchCount(FetchDescriptor<TransactionRecord>()) == 0)
    }

    @Test func rejectsCurrencyMismatch() throws {
        let store = try TestStore()
        let draft = TransactionDraft(
            amount: Money(minorUnits: 100, currency: CurrencyCode(rawValue: "USD")),
            accountID: try store.cash().id,
            categoryID: try store.expenseCategory().id
        )
        #expect(throws: AppError.validation(.currencyMismatch)) { try store.app.transactions.create(draft) }
    }

    @Test func transferMovesMoneyWithoutCashFlow() throws {
        let store = try TestStore()
        let cash = try store.cash()
        let bank = try store.app.accounts.create(AccountDraft(name: "Bank", type: .bank, openingBalance: .inr(1_000)))

        try store.app.transactions.create(TransactionDraft(amount: .inr(400), type: .transfer, accountID: bank.id, destinationAccountID: cash.id))

        let balances = try store.app.accounts.balances()
        #expect(balances[bank.id] == .inr(600))
        #expect(balances[cash.id] == .inr(400))
        #expect(try store.app.accounts.netWorth() == .inr(1_000))
        let flow = BalanceCalculator.cashFlow(of: try store.app.transactions.ledgerLines(in: nil))
        #expect(flow == CashFlowSummary())
    }

    @Test func queryFiltersAndSearch() throws {
        let store = try TestStore()
        let cash = try store.cash()
        let food = try store.expenseCategory("food")
        let travel = try store.expenseCategory("travel")
        let salary = try store.incomeCategory()
        let day = TestCalendar.date(2026, 9, 10)

        try store.app.transactions.create(TransactionDraft(amount: .inr(300), date: day, accountID: cash.id, categoryID: food.id, merchant: "Saravana Bhavan"))
        try store.app.transactions.create(TransactionDraft(amount: .inr(5_000), date: day, accountID: cash.id, categoryID: travel.id, merchant: "IndiGo"))
        try store.app.transactions.create(TransactionDraft(amount: .inr(90_000), type: .income, date: day, accountID: cash.id, categoryID: salary.id))
        try store.app.transactions.create(TransactionDraft(amount: .inr(50), date: TestCalendar.date(2026, 8, 10), accountID: cash.id, categoryID: food.id))

        let september = PeriodCalculator(calendar: TestCalendar.utc).month(containing: day)
        let repo = store.app.transactions
        #expect(try repo.transactions(matching: TransactionQuery(interval: september)).count == 3)
        #expect(try repo.transactions(matching: TransactionQuery(interval: september, types: [.expense])).count == 2)
        #expect(try repo.transactions(matching: TransactionQuery(categoryIDs: [food.id])).count == 2)
        #expect(try repo.transactions(matching: TransactionQuery(searchText: "saravana")).map(\.merchant) == ["Saravana Bhavan"])
        #expect(try repo.transactions(matching: TransactionQuery(types: [.expense, .income], limit: 2)).count == 2)
        #expect(try repo.transactions(matching: .recent(1)).count == 1)
    }

    @Test func duplicateDetection() throws {
        let store = try TestStore()
        let draft = TransactionDraft(
            amount: .inr(120), date: .now, accountID: try store.cash().id,
            categoryID: try store.expenseCategory().id, merchant: "Chai Point"
        )
        #expect(try store.app.transactions.possibleDuplicate(of: draft, within: 120) == nil)
        try store.app.transactions.create(draft)
        var again = draft
        again.merchant = "chai point"
        again.date = draft.date.addingTimeInterval(30)
        #expect(try store.app.transactions.possibleDuplicate(of: again, within: 120) != nil)
        again.amount = .inr(121)
        #expect(try store.app.transactions.possibleDuplicate(of: again, within: 120) == nil)
    }

    @Test func updateAndDelete() throws {
        let store = try TestStore()
        let cash = try store.cash()
        let food = try store.expenseCategory()
        let record = try store.app.transactions.create(TransactionDraft(amount: .inr(100), accountID: cash.id, categoryID: food.id))

        var draft = TransactionDraft(amount: .inr(175), accountID: cash.id, categoryID: food.id, note: "Dinner")
        draft.date = record.date
        try store.app.transactions.update(record, with: draft)
        #expect(record.amount == .inr(175))
        #expect(record.note == "Dinner")

        try store.app.transactions.delete(record)
        #expect(try store.context.fetchCount(FetchDescriptor<TransactionRecord>()) == 0)
        #expect(try store.app.accounts.balance(of: cash) == .zero(.inr))
    }

    // MARK: Accounts & categories

    @Test func accountWithHistoryCannotBeDeleted() throws {
        let store = try TestStore()
        let cash = try store.cash()
        try store.app.transactions.create(TransactionDraft(amount: .inr(1), accountID: cash.id, categoryID: try store.expenseCategory().id))
        #expect(throws: AppError.accountHasTransactions(count: 1)) { try store.app.accounts.delete(cash) }

        try store.app.accounts.setArchived(cash, true)
        #expect(try store.app.accounts.accounts(includeArchived: false).isEmpty)
    }

    @Test func duplicateNamesAreRejected() throws {
        let store = try TestStore()
        #expect(throws: AppError.duplicate(entity: "Account", name: "cash")) {
            try store.app.accounts.create(AccountDraft(name: " cash ", type: .cash, openingBalance: .zero(.inr)))
        }
        #expect(throws: AppError.validation(.emptyName)) {
            try store.app.categories.create(CategoryDraft(name: "  ", type: .expense, symbolName: "star", tint: .sand))
        }
    }

    @Test func deletingCategoryRemovesItsBudget() throws {
        let store = try TestStore()
        let pets = try store.app.categories.create(CategoryDraft(name: "Pets", type: .expense, symbolName: "pawprint", tint: .ochre))
        try store.app.budgets.create(BudgetDraft(name: "", limit: .inr(2_000), categoryID: pets.id))
        #expect(try store.app.budgets.budgets(includeInactive: true).count == 1)

        try store.app.categories.delete(pets)
        #expect(try store.app.budgets.budgets(includeInactive: true).isEmpty)
    }

    // MARK: Budgets

    @Test func budgetStatusCountsSubcategoriesAndPeriodOnly() throws {
        let store = try TestStore()
        let cash = try store.cash()
        let food = try store.expenseCategory("food")
        let coffee = try store.app.categories.create(CategoryDraft(name: "Coffee", type: .expense, symbolName: "cup.and.saucer", tint: .sand, parentID: food.id))
        let now = TestCalendar.date(2026, 9, 16)

        try store.app.transactions.create(TransactionDraft(amount: .inr(1_000), date: TestCalendar.date(2026, 9, 3), accountID: cash.id, categoryID: food.id))
        try store.app.transactions.create(TransactionDraft(amount: .inr(500), date: TestCalendar.date(2026, 9, 5), accountID: cash.id, categoryID: coffee.id))
        try store.app.transactions.create(TransactionDraft(amount: .inr(9_999), date: TestCalendar.date(2026, 8, 30), accountID: cash.id, categoryID: food.id))
        try store.app.transactions.create(TransactionDraft(amount: .inr(700), date: TestCalendar.date(2026, 9, 6), accountID: cash.id, categoryID: try store.expenseCategory("travel").id))

        let foodBudget = try store.app.budgets.create(BudgetDraft(name: "", limit: .inr(2_000), categoryID: food.id))
        let overall = try store.app.budgets.create(BudgetDraft(name: "Monthly", limit: .inr(2_000)))

        let foodStatus = try store.app.budgets.status(of: foodBudget, at: now)
        #expect(foodStatus.spentMinor == 150_000)
        #expect(foodStatus.level == .onTrack)
        #expect(foodBudget.name == "Food & Dining")

        let overallStatus = try store.app.budgets.status(of: overall, at: now)
        #expect(overallStatus.spentMinor == 220_000)
        #expect(overallStatus.level == .over)

        #expect(try store.app.budgets.budgets(includeInactive: false).first?.id == overall.id)
        #expect(throws: AppError.duplicate(entity: "Budget", name: "Monthly")) {
            try store.app.budgets.create(BudgetDraft(name: "Another", limit: .inr(1)))
        }
    }

    // MARK: Goals

    @Test func goalCompletesOnceAndReopensOnWithdrawal() throws {
        let store = try TestStore()
        let goal = try store.app.goals.create(SavingsGoalDraft(name: "MacBook", symbolName: "laptopcomputer", tint: .indigo, target: .inr(1_000)))

        let first = try store.app.goals.contribute(.inr(600), to: goal, on: .now, note: nil)
        #expect(first.didJustComplete == false)
        #expect(first.progress.fraction == 0.6)

        let second = try store.app.goals.contribute(.inr(400), to: goal, on: .now, note: nil)
        #expect(second.didJustComplete)
        #expect(goal.isCompleted)

        let third = try store.app.goals.contribute(.inr(1), to: goal, on: .now, note: nil)
        #expect(third.didJustComplete == false)

        #expect(throws: AppError.validation(.amountTooLarge)) {
            try store.app.goals.contribute(.inr(-5_000), to: goal, on: .now, note: nil)
        }
        try store.app.goals.contribute(.inr(-500), to: goal, on: .now, note: "Emergency")
        #expect(goal.isCompleted == false)

        try store.app.goals.delete(goal)
        #expect(try store.context.fetchCount(FetchDescriptor<GoalContribution>()) == 0)
    }

    // MARK: Recurring

    @Test func recurrenceEngineCatchesUpOnceAndIsIdempotent() throws {
        let store = try TestStore()
        let cash = try store.cash()
        let rent = try store.expenseCategory("rent")
        let rule = try store.app.recurring.create(RecurringDraft(
            template: TransactionDraft(amount: .inr(25_000), date: TestCalendar.date(2026, 6, 1), accountID: cash.id, categoryID: rent.id, merchant: "Landlord"),
            frequency: .monthly
        ))

        let engine = RecurrenceEngine(context: store.context, calendar: TestCalendar.utc)
        let now = TestCalendar.date(2026, 9, 17)
        #expect(try engine.processDueRules(now: now) == 4) // Jun, Jul, Aug, Sep
        #expect(try engine.processDueRules(now: now) == 0)
        #expect(rule.generatedTransactions.count == 4)
        #expect(rule.nextDueDate == TestCalendar.date(2026, 10, 1))
        #expect(try store.app.accounts.balance(of: cash) == .inr(-100_000))
        #expect(try store.app.recurring.upcoming(within: 30, from: now).count == 1)

        // Deleting the rule keeps history.
        try store.app.recurring.delete(rule)
        #expect(try store.context.fetchCount(FetchDescriptor<TransactionRecord>()) == 4)
    }

    @Test func pausedRulesDoNotGenerate() throws {
        let store = try TestStore()
        let rule = try store.app.recurring.create(RecurringDraft(
            template: TransactionDraft(amount: .inr(199), date: TestCalendar.date(2026, 9, 1), accountID: try store.cash().id, categoryID: try store.expenseCategory("entertainment").id),
            frequency: .weekly
        ))
        try store.app.recurring.setPaused(rule, true)
        let engine = RecurrenceEngine(context: store.context, calendar: TestCalendar.utc)
        #expect(try engine.processDueRules(now: TestCalendar.date(2026, 9, 30)) == 0)
    }

    @Test func endDateBeforeStartIsRejected() throws {
        let store = try TestStore()
        let draft = RecurringDraft(
            template: TransactionDraft(amount: .inr(1), date: TestCalendar.date(2026, 9, 10), accountID: try store.cash().id, categoryID: try store.expenseCategory().id),
            frequency: .daily,
            endDate: TestCalendar.date(2026, 9, 1)
        )
        #expect(throws: AppError.validation(.endBeforeStart)) { try store.app.recurring.create(draft) }
    }
}

import Foundation
import Testing
@testable import MoneyLog

@Suite("BalanceCalculator")
struct BalanceCalculatorTests {
    let bank = UUID()
    let cash = UUID()

    func line(_ amount: Int64, _ type: TransactionType, from: UUID?, to: UUID? = nil) -> LedgerLine {
        LedgerLine(amountMinor: amount, type: type, date: .now, accountID: from, destinationAccountID: to, categoryID: nil)
    }

    @Test func incomeExpenseAndTransfer() throws {
        let lines = [
            line(10_000, .income, from: bank),
            line(2_500, .expense, from: bank),
            line(3_000, .transfer, from: bank, to: cash),
            line(500, .expense, from: cash),
        ]
        let balances = BalanceCalculator.balances(openingBalances: [bank: 1_000, cash: 0], lines: lines)
        // Unwrap explicitly: comparing an Optional<Int64> against an integer literal
        // inside #expect erases the literal's type and never matches.
        let bankBalance: Int64 = try #require(balances[bank])
        let cashBalance: Int64 = try #require(balances[cash])
        #expect(bankBalance == 1_000 + 10_000 - 2_500 - 3_000)
        #expect(cashBalance == 3_000 - 500)
        #expect(BalanceCalculator.delta(of: lines[2], on: cash) == 3_000)
    }

    @Test func transfersAreNotCashFlow() {
        let summary = BalanceCalculator.cashFlow(of: [
            line(10_000, .income, from: bank),
            line(4_000, .expense, from: bank),
            line(9_999, .transfer, from: bank, to: cash),
        ])
        #expect(summary.incomeMinor == 10_000)
        #expect(summary.expenseMinor == 4_000)
        #expect(summary.netMinor == 6_000)
        #expect(summary.savingsRate == 0.6)
    }

    @Test func unknownAccountsAreIgnored() {
        let balances = BalanceCalculator.balances(openingBalances: [bank: 0], lines: [line(100, .expense, from: UUID())])
        #expect(balances == [bank: 0])
    }
}

@Suite("BudgetCalculator")
struct BudgetCalculatorTests {
    let periods = PeriodCalculator(calendar: TestCalendar.utc)
    // September 2026 has 30 days.
    var september: DateInterval { periods.month(containing: TestCalendar.date(2026, 9, 1)) }

    func status(spent: Int64, limit: Int64 = 30_000, on day: Int) -> BudgetStatus {
        BudgetCalculator.status(
            limitMinor: limit,
            spentMinor: spent,
            period: september,
            alertThreshold: 0.8,
            now: TestCalendar.date(2026, 9, day, 0),
            periods: periods
        )
    }

    @Test func underPaceIsOnTrack() {
        let s = status(spent: 10_000, on: 16) // halfway through the month, 33% spent
        #expect(s.level == .onTrack)
        #expect(s.expectedProgress == 0.5)
        #expect(s.paceDeltaMinor == 5_000)
        #expect(s.daysRemaining == 15)
        #expect(s.dailyAllowanceMinor == 20_000 / 15)
    }

    @Test func thresholdIsApproaching() {
        #expect(status(spent: 24_000, on: 20).level == .approaching)
        #expect(status(spent: 30_000, on: 20).level == .approaching) // exactly at limit is not over
    }

    @Test func overLimit() {
        let s = status(spent: 31_000, on: 20)
        #expect(s.level == .over)
        #expect(s.overspentMinor == 1_000)
        #expect(s.dailyAllowanceMinor == 0)
    }

    @Test func zeroLimitDoesNotDivideByZero() {
        #expect(status(spent: 0, limit: 0, on: 5).progress == 0)
        #expect(status(spent: 1, limit: 0, on: 5).level == .over)
    }

    @Test func goalProgressClampsAndProjects() {
        let goal = GoalProgress(savedMinor: 25_000, targetMinor: 100_000, targetDate: TestCalendar.date(2027, 3, 17), createdAt: .now)
        #expect(goal.fraction == 0.25)
        #expect(goal.remainingMinor == 75_000)
        #expect(goal.requiredMonthlyMinor(now: TestCalendar.date(2026, 9, 17), calendar: TestCalendar.utc) == 12_500)
        #expect(GoalProgress(savedMinor: 150, targetMinor: 100, targetDate: nil, createdAt: .now).fraction == 1)
    }
}

@Suite("RecurrenceSchedule")
struct RecurrenceScheduleTests {
    @Test func monthEndDoesNotDrift() {
        let schedule = RecurrenceSchedule(start: TestCalendar.date(2026, 1, 31), frequency: .monthly, end: nil, calendar: TestCalendar.utc)
        #expect(schedule.occurrence(at: 1) == TestCalendar.date(2026, 2, 28))
        #expect(schedule.occurrence(at: 2) == TestCalendar.date(2026, 3, 31))
    }

    @Test func respectsEndDateAndLimit() {
        let schedule = RecurrenceSchedule(
            start: TestCalendar.date(2026, 9, 1),
            frequency: .weekly,
            end: TestCalendar.date(2026, 9, 20),
            calendar: TestCalendar.utc
        )
        let due = schedule.dueOccurrences(startingAt: 0, through: TestCalendar.date(2026, 12, 1), limit: 100)
        #expect(due.map(\.index) == [0, 1, 2])
        #expect(schedule.occurrence(at: 3) == nil)
        #expect(schedule.dueOccurrences(startingAt: 0, through: TestCalendar.date(2026, 12, 1), limit: 2).count == 2)
    }

    @Test func biweeklyAndQuarterlySteps() {
        let start = TestCalendar.date(2026, 1, 1)
        let biweekly = RecurrenceSchedule(start: start, frequency: .biweekly, end: nil, calendar: TestCalendar.utc)
        #expect(biweekly.occurrence(at: 1) == TestCalendar.date(2026, 1, 15))
        let quarterly = RecurrenceSchedule(start: start, frequency: .quarterly, end: nil, calendar: TestCalendar.utc)
        #expect(quarterly.occurrence(at: 1) == TestCalendar.date(2026, 4, 1))
    }
}

@Suite("TransactionValidator")
struct TransactionValidatorTests {
    let account = UUID()
    let category = UUID()

    @Test func rejectsNonPositiveAmount() {
        let draft = TransactionDraft(amount: .zero(.inr), accountID: account, categoryID: category)
        #expect(throws: AppError.validation(.amountNotPositive)) { try TransactionValidator.validate(draft) }
    }

    @Test func expenseRequiresCategory() {
        let draft = TransactionDraft(amount: .inr(10), accountID: account)
        #expect(throws: AppError.validation(.missingCategory)) { try TransactionValidator.validate(draft) }
    }

    @Test func transferRules() {
        var draft = TransactionDraft(amount: .inr(10), type: .transfer, accountID: account)
        #expect(throws: AppError.validation(.missingDestinationAccount)) { try TransactionValidator.validate(draft) }
        draft.destinationAccountID = account
        #expect(throws: AppError.validation(.transferToSameAccount)) { try TransactionValidator.validate(draft) }
        draft.destinationAccountID = UUID()
        #expect(throws: Never.self) { try TransactionValidator.validate(draft) }
    }

    @Test func rejectsAbsurdDates() {
        let draft = TransactionDraft(amount: .inr(10), date: .distantFuture, accountID: account, categoryID: category)
        #expect(throws: AppError.validation(.dateOutOfRange)) { try TransactionValidator.validate(draft) }
    }
}

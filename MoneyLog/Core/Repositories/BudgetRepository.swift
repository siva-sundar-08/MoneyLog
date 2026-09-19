import Foundation
import SwiftData

struct BudgetDraft: Equatable, Sendable {
    var name: String
    var limit: Money
    var period: BudgetPeriod = .monthly
    // Leave empty for a budget that covers all your spending.
    var categoryID: UUID?
    var alertThreshold: Double = 0.8
    var rollsOver: Bool = false
}

// Reads and writes budgets, and works out how each one is doing this month.
@MainActor
protocol BudgetRepository: AnyObject {
    func budgets(includeInactive: Bool) throws -> [Budget]
    @discardableResult func create(_ draft: BudgetDraft) throws -> Budget
    func update(_ budget: Budget, with draft: BudgetDraft) throws
    func delete(_ budget: Budget) throws
    func status(of budget: Budget, at now: Date) throws -> BudgetStatus
}

@MainActor
final class SwiftDataBudgetRepository: BudgetRepository {
    private let context: ModelContext
    private let periods: PeriodCalculator

    init(context: ModelContext, periods: PeriodCalculator = PeriodCalculator()) {
        self.context = context
        self.periods = periods
    }

    func budgets(includeInactive: Bool = false) throws -> [Budget] {
        let descriptor = FetchDescriptor<Budget>(
            predicate: includeInactive ? nil : #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        // Overall budget first, then category budgets.
        return try context.fetchOrThrow(descriptor).sorted { lhs, rhs in
            lhs.isOverall && !rhs.isOverall
        }
    }

    @discardableResult
    func create(_ draft: BudgetDraft) throws -> Budget {
        let category = try validate(draft, excluding: nil)
        let budget = Budget(
            name: draft.name.trimmedNilIfEmpty ?? category?.name ?? "",
            limit: draft.limit,
            period: draft.period,
            alertThreshold: draft.alertThreshold,
            rollsOver: draft.rollsOver
        )
        context.insert(budget)
        budget.category = category
        try context.saveOrRollback()
        return budget
    }

    func update(_ budget: Budget, with draft: BudgetDraft) throws {
        let category = try validate(draft, excluding: budget.id)
        budget.name = draft.name.trimmedNilIfEmpty ?? category?.name ?? budget.name
        budget.limit = draft.limit
        budget.period = draft.period
        budget.alertThreshold = draft.alertThreshold
        budget.rollsOver = draft.rollsOver
        budget.category = category
        try context.saveOrRollback()
    }

    func delete(_ budget: Budget) throws {
        context.delete(budget)
        try context.saveOrRollback(operation: .delete)
    }

    func status(of budget: Budget, at now: Date = .now) throws -> BudgetStatus {
        let period = periods.interval(for: budget.period, containing: now)
        let start = period.start
        let end = period.end
        let expenseRaw = TransactionType.expense.rawValue
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.typeRaw == expenseRaw && $0.date >= start && $0.date < end }
        )
        let expenses = try context.fetchOrThrow(descriptor)

        let spent: Int64
        if let category = budget.category {
            let covered = category.subtreeIDs
            spent = expenses.reduce(0) { total, record in
                guard let id = record.category?.id, covered.contains(id) else { return total }
                return total + record.amountMinor
            }
        } else {
            spent = expenses.reduce(0) { $0 + $1.amountMinor }
        }

        return BudgetCalculator.status(
            limitMinor: budget.limitMinor,
            spentMinor: spent,
            period: period,
            alertThreshold: budget.alertThreshold,
            now: now,
            periods: periods
        )
    }

    private func validate(_ draft: BudgetDraft, excluding id: UUID?) throws -> TransactionCategory? {
        guard draft.limit.minorUnits > 0 else { throw AppError.validation(.amountNotPositive) }
        guard draft.limit.minorUnits <= TransactionValidator.maximumMinorUnits else { throw AppError.validation(.amountTooLarge) }
        guard (0.01...1).contains(draft.alertThreshold) else { throw AppError.validation(.invalidThreshold) }

        var category: TransactionCategory?
        if let categoryID = draft.categoryID {
            guard let resolved = try context.category(id: categoryID) else { throw AppError.validation(.missingCategory) }
            guard resolved.type == .expense else { throw AppError.validation(.categoryTypeMismatch) }
            category = resolved
        } else if draft.name.trimmedNilIfEmpty == nil {
            throw AppError.validation(.emptyName)
        }

        // One active budget per (category, period).
        let clash = try budgets(includeInactive: false).first {
            $0.id != id && $0.category?.id == draft.categoryID && $0.period == draft.period
        }
        if let clash { throw AppError.duplicate(entity: "Budget", name: clash.name) }
        return category
    }
}

import Foundation
import SwiftData

struct SavingsGoalDraft: Equatable, Sendable {
    var name: String
    var symbolName: String
    var tint: TintKey
    var target: Money
    var targetDate: Date?
    var linkedAccountID: UUID?
}

// What happened when money was added to a goal.
//
// `didJustComplete` exists so the screen can celebrate once, on the deposit that
// finished the goal — not every time it redraws afterwards.
struct ContributionOutcome: Equatable, Sendable {
    let progress: GoalProgress
    let didJustComplete: Bool
}

@MainActor
protocol SavingsGoalRepository: AnyObject {
    func goals(includeArchived: Bool) throws -> [SavingsGoal]
    @discardableResult func create(_ draft: SavingsGoalDraft) throws -> SavingsGoal
    func update(_ goal: SavingsGoal, with draft: SavingsGoalDraft) throws
    @discardableResult func contribute(_ amount: Money, to goal: SavingsGoal, on date: Date, note: String?) throws -> ContributionOutcome
    func removeContribution(_ contribution: GoalContribution) throws
    func setArchived(_ goal: SavingsGoal, _ archived: Bool) throws
    func delete(_ goal: SavingsGoal) throws
}

@MainActor
final class SwiftDataSavingsGoalRepository: SavingsGoalRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func goals(includeArchived: Bool = false) throws -> [SavingsGoal] {
        let descriptor = FetchDescriptor<SavingsGoal>(
            predicate: includeArchived ? nil : #Predicate { $0.isArchived == false },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        // Active goals first, completed ones after.
        return try context.fetchOrThrow(descriptor).sorted { !$0.isCompleted && $1.isCompleted }
    }

    @discardableResult
    func create(_ draft: SavingsGoalDraft) throws -> SavingsGoal {
        let (name, account) = try validate(draft)
        let goal = SavingsGoal(
            name: name,
            symbolName: draft.symbolName,
            tint: draft.tint,
            target: draft.target,
            targetDate: draft.targetDate
        )
        context.insert(goal)
        goal.linkedAccount = account
        try context.saveOrRollback()
        return goal
    }

    func update(_ goal: SavingsGoal, with draft: SavingsGoalDraft) throws {
        let (name, account) = try validate(draft)
        goal.name = name
        goal.symbolName = draft.symbolName
        goal.tint = draft.tint
        goal.target = draft.target
        goal.targetDate = draft.targetDate
        goal.linkedAccount = account
        refreshCompletion(of: goal, at: .now)
        try context.saveOrRollback()
    }

    @discardableResult
    func contribute(_ amount: Money, to goal: SavingsGoal, on date: Date = .now, note: String? = nil) throws -> ContributionOutcome {
        guard amount.minorUnits != 0 else { throw AppError.validation(.amountNotPositive) }
        guard amount.currency == goal.currency else { throw AppError.validation(.currencyMismatch) }
        // Withdrawals can't take the goal below zero.
        guard goal.saved.minorUnits + amount.minorUnits >= 0 else { throw AppError.validation(.amountTooLarge) }

        let wasComplete = goal.isCompleted
        let contribution = GoalContribution(amountMinor: amount.minorUnits, date: date, note: note?.trimmedNilIfEmpty)
        context.insert(contribution)
        contribution.goal = goal
        refreshCompletion(of: goal, at: date)
        try context.saveOrRollback()

        return ContributionOutcome(progress: goal.progress, didJustComplete: !wasComplete && goal.isCompleted)
    }

    func removeContribution(_ contribution: GoalContribution) throws {
        let goal = contribution.goal
        context.delete(contribution)
        if let goal {
            goal.contributions.removeAll { $0.id == contribution.id }
            refreshCompletion(of: goal, at: .now)
        }
        try context.saveOrRollback(operation: .delete)
    }

    func setArchived(_ goal: SavingsGoal, _ archived: Bool) throws {
        goal.isArchived = archived
        try context.saveOrRollback()
    }

    func delete(_ goal: SavingsGoal) throws {
        context.delete(goal)
        try context.saveOrRollback(operation: .delete)
    }

    private func refreshCompletion(of goal: SavingsGoal, at date: Date) {
        if goal.progress.isReached {
            if goal.completedAt == nil { goal.completedAt = date }
        } else {
            goal.completedAt = nil
        }
    }

    private func validate(_ draft: SavingsGoalDraft) throws -> (String, Account?) {
        guard let name = draft.name.trimmedNilIfEmpty else { throw AppError.validation(.emptyName) }
        guard draft.target.minorUnits > 0 else { throw AppError.validation(.amountNotPositive) }
        guard draft.target.minorUnits <= TransactionValidator.maximumMinorUnits else { throw AppError.validation(.amountTooLarge) }
        var account: Account?
        if let id = draft.linkedAccountID {
            guard let resolved = try context.account(id: id) else { throw AppError.validation(.missingAccount) }
            account = resolved
        }
        return (name, account)
    }
}

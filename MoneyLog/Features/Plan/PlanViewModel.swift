import Foundation
import Observation

// Runs the Plan tab: loads budgets with their current progress, loads goals, and
// handles saving, deleting and adding money to a goal.
@MainActor
@Observable
final class PlanViewModel {
    struct BudgetRow: Identifiable {
        let budget: Budget
        let status: BudgetStatus
        var id: UUID { budget.id }
        var isOverall: Bool { budget.isOverall }
    }

    struct GoalRow: Identifiable {
        let goal: SavingsGoal
        let progress: GoalProgress
        let requiredMonthlyMinor: Int64?
        var id: UUID { goal.id }
    }

    private(set) var budgetRows: [BudgetRow] = []
    private(set) var goalRows: [GoalRow] = []
    private(set) var expenseCategories: [TransactionCategory] = []
    private(set) var accounts: [Account] = []
    private(set) var isLoaded = false
    var errorMessage: String?
    // Set on the deposit that completes a goal, so the screen celebrates once.
    var celebratingGoalID: UUID?

    private let container: AppContainer
    // Last known state of each budget, so a warning fires on the crossing only.
    private var lastLevels: [UUID: BudgetStatus.Level] = [:]

    init(container: AppContainer) {
        self.container = container
    }

    var currency: CurrencyCode { container.currency.currentCurrency }
    var overallRow: BudgetRow? { budgetRows.first { $0.isOverall } }
    var categoryRows: [BudgetRow] { budgetRows.filter { !$0.isOverall } }

    func load(now: Date = .now) {
        do {
            let budgets = try container.budgets.budgets(includeInactive: false)
            var rows: [BudgetRow] = []
            for budget in budgets {
                let status = try container.budgets.status(of: budget, at: now)
                rows.append(BudgetRow(budget: budget, status: status))
                announceThresholdIfNeeded(for: budget, status: status)
            }
            budgetRows = rows

            let calendar = container.periods.calendar
            goalRows = try container.goals.goals(includeArchived: false).map { goal in
                let progress = goal.progress
                return GoalRow(
                    goal: goal,
                    progress: progress,
                    requiredMonthlyMinor: progress.requiredMonthlyMinor(now: now, calendar: calendar)
                )
            }

            expenseCategories = try container.categories.categories(of: .expense, includeArchived: false)
            accounts = try container.accounts.accounts(includeArchived: false)
            errorMessage = nil
            isLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            isLoaded = true
        }
    }

    // MARK: Budgets

    func saveBudget(_ draft: BudgetDraft, editing budget: Budget?) -> Bool {
        do {
            if let budget {
                try container.budgets.update(budget, with: draft)
            } else {
                try container.budgets.create(draft)
            }
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteBudget(_ budget: Budget) {
        do {
            try container.budgets.delete(budget)
            Haptics.play(.deleted)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Buzzes once when a budget first goes amber or red.
    //
    // Without the remembered state this would fire on every reload, and an app that
    // buzzes every time you open it gets its haptics switched off.
    private func announceThresholdIfNeeded(for budget: Budget, status: BudgetStatus) {
        let previous = lastLevels[budget.id]
        lastLevels[budget.id] = status.level
        guard let previous, previous != status.level, status.level != .onTrack else { return }
        Haptics.play(.budgetThreshold)
    }

    // MARK: Goals

    func saveGoal(_ draft: SavingsGoalDraft, editing goal: SavingsGoal?) -> Bool {
        do {
            if let goal {
                try container.goals.update(goal, with: draft)
            } else {
                try container.goals.create(draft)
            }
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func contribute(_ money: Money, to goal: SavingsGoal, note: String?) -> Bool {
        do {
            let outcome = try container.goals.contribute(money, to: goal, on: .now, note: note)
            if outcome.didJustComplete {
                Haptics.play(.goalCompleted)
                celebratingGoalID = goal.id
            }
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteGoal(_ goal: SavingsGoal) {
        do {
            try container.goals.delete(goal)
            Haptics.play(.deleted)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

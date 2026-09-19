import Foundation
import Observation

struct AccountSummary: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: AccountType
    let tint: TintKey
    let balance: Money
}

struct BudgetSummary: Equatable {
    let id: UUID
    let name: String
    let limit: Money
    let status: BudgetStatus
    let isOverall: Bool
}

struct GoalSummary: Identifiable, Equatable {
    let id: UUID
    let name: String
    let symbolName: String
    let tint: TintKey
    let saved: Money
    let target: Money
    let progress: GoalProgress
}

struct DashboardSnapshot {
    var currency: CurrencyCode = .default
    var netWorth: Money = .zero()
    var monthIncome: Money = .zero()
    var monthExpense: Money = .zero()
    var monthInterval = DateInterval()
    // The same stretch of last month — up to the 18th if today is the 18th.
    // Comparing a half-finished month against a whole one would always look good.
    var previousMonthToDateExpense: Money = .zero()
    var previousMonthExpense: Money = .zero()
    var dailySpend: [DailySpend] = []
    var todayIndex: Int?
    var accounts: [AccountSummary] = []
    var budget: BudgetSummary?
    var goal: GoalSummary?
    var recent: [TransactionRecord] = []
    var hasAnyTransactions = false

    var monthNet: Money { monthIncome - monthExpense }
}

// Works out everything the home screen shows.
//
// A "view model" is just an object that prepares data for one screen: it asks the
// repositories for records, does the arithmetic, and hands back plain values the
// view can draw. Keeping it separate means the maths can be tested without
// launching the app, and the view stays easy to read.
//
// @Observable is what lets SwiftUI notice when these values change and redraw.
@MainActor
@Observable
final class TodayViewModel {
    private(set) var snapshot = DashboardSnapshot()
    private(set) var isLoaded = false
    var errorMessage: String?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    private var periods: PeriodCalculator { container.periods }
    private var calendar: Calendar { container.periods.calendar }

    func load(now: Date = .now) {
        do {
            let currency = container.currency.currentCurrency
            let month = periods.month(containing: now)
            let previousMonth = periods.previous(.month, before: now)

            let monthLines = try container.transactions.ledgerLines(in: month)
            let cashFlow = BalanceCalculator.cashFlow(of: monthLines)

            var snapshot = DashboardSnapshot()
            snapshot.currency = currency
            snapshot.monthInterval = month
            snapshot.monthIncome = Money(minorUnits: cashFlow.incomeMinor, currency: currency)
            snapshot.monthExpense = Money(minorUnits: cashFlow.expenseMinor, currency: currency)
            snapshot.netWorth = try container.accounts.netWorth()

            let previousLines = try container.transactions.ledgerLines(in: previousMonth)
            snapshot.previousMonthExpense = Money(
                minorUnits: BalanceCalculator.cashFlow(of: previousLines).expenseMinor,
                currency: currency
            )
            snapshot.previousMonthToDateExpense = Money(
                minorUnits: expenseTotal(of: previousLines, upToSameElapsedTimeAs: now, in: month, previous: previousMonth),
                currency: currency
            )

            snapshot.dailySpend = dailySpend(from: monthLines, in: month)
            snapshot.todayIndex = snapshot.dailySpend.firstIndex {
                calendar.isDate($0.date, inSameDayAs: now)
            }

            let balances = try container.accounts.balances()
            snapshot.accounts = try container.accounts.accounts(includeArchived: false).map { account in
                AccountSummary(
                    id: account.id,
                    name: account.name,
                    type: account.type,
                    tint: account.tint,
                    balance: balances[account.id] ?? account.openingBalance
                )
            }

            snapshot.budget = try primaryBudget(now: now)
            snapshot.goal = try primaryGoal()
            snapshot.recent = try container.transactions.transactions(matching: .recent(5))
            snapshot.hasAnyTransactions = !snapshot.recent.isEmpty

            self.snapshot = snapshot
            self.isLoaded = true
            self.errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            isLoaded = true
        }
    }

    // MARK: Derived copy

    // The sentence under the balance. It answers the question people actually have
    // — "am I doing all right?" — which no chart answers on its own.
    var insight: String {
        let snapshot = snapshot
        if let budget = snapshot.budget {
            let status = budget.status
            let delta = Money(minorUnits: abs(status.paceDeltaMinor), currency: snapshot.currency)
            switch status.level {
            case .over:
                let over = Money(minorUnits: status.overspentMinor, currency: snapshot.currency)
                return String(localized: "insight.over", defaultValue: "You're \(over.formatted()) past your \(budget.name.lowercased()) budget.")
            case .approaching, .onTrack:
                if status.paceDeltaMinor >= 0 {
                    return String(localized: "insight.underPace", defaultValue: "You're \(delta.formatted()) under pace with \(status.daysRemaining) days to go.")
                } else {
                    return String(localized: "insight.aheadPace", defaultValue: "You're \(delta.formatted()) ahead of pace with \(status.daysRemaining) days to go.")
                }
            }
        }

        guard snapshot.hasAnyTransactions else {
            return String(localized: "insight.empty", defaultValue: "Add your first expense to see where your money goes.")
        }

        let current = snapshot.monthExpense.minorUnits
        let previous = snapshot.previousMonthToDateExpense.minorUnits
        guard previous > 0 else {
            return String(localized: "insight.firstMonth", defaultValue: "\(snapshot.monthExpense.formatted()) spent so far this month.")
        }
        let change = Double(current - previous) / Double(previous)
        let percent = abs(change).formatted(.percent.precision(.fractionLength(0)))
        if change > 0.02 {
            return String(localized: "insight.higher", defaultValue: "Spending is \(percent) higher than this time last month.")
        } else if change < -0.02 {
            return String(localized: "insight.lower", defaultValue: "Spending is \(percent) lower than this time last month.")
        }
        return String(localized: "insight.steady", defaultValue: "Spending is holding steady against last month.")
    }

    var monthName: String {
        snapshot.monthInterval.start.formatted(.dateTime.month(.wide))
    }

    // MARK: Helpers

    private func dailySpend(from lines: [LedgerLine], in month: DateInterval) -> [DailySpend] {
        var totals: [Date: Int64] = [:]
        for line in lines where line.type == .expense {
            let day = calendar.startOfDay(for: line.date)
            totals[day, default: 0] += line.amountMinor
        }
        return periods.days(in: month).map { day in
            DailySpend(date: day, amountMinor: totals[day] ?? 0)
        }
    }

    private func expenseTotal(
        of lines: [LedgerLine],
        upToSameElapsedTimeAs now: Date,
        in month: DateInterval,
        previous: DateInterval
    ) -> Int64 {
        let elapsed = now.timeIntervalSince(month.start)
        let cutoff = previous.start.addingTimeInterval(min(elapsed, previous.duration))
        return lines.reduce(Int64(0)) { total, line in
            guard line.type == .expense, line.date <= cutoff else { return total }
            return total + line.amountMinor
        }
    }

    private func primaryBudget(now: Date) throws -> BudgetSummary? {
        let budgets = try container.budgets.budgets(includeInactive: false)
        guard let budget = budgets.first(where: \.isOverall) ?? budgets.first else { return nil }
        let status = try container.budgets.status(of: budget, at: now)
        return BudgetSummary(
            id: budget.id,
            name: budget.name,
            limit: budget.limit,
            status: status,
            isOverall: budget.isOverall
        )
    }

    private func primaryGoal() throws -> GoalSummary? {
        let goals = try container.goals.goals(includeArchived: false)
        guard let goal = goals.first(where: { !$0.isCompleted }) ?? goals.first else { return nil }
        return GoalSummary(
            id: goal.id,
            name: goal.name,
            symbolName: goal.symbolName,
            tint: goal.tint,
            saved: goal.saved,
            target: goal.target,
            progress: goal.progress
        )
    }
}

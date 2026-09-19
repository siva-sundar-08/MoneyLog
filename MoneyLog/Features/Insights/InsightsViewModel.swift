import Foundation
import Observation

struct CategorySlice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let symbolName: String
    let slot: Int
    let amountMinor: Int64
    let previousAmountMinor: Int64
    let share: Double

    // How this compares with the same category last month. Nil if it's new.
    var change: Double? {
        guard previousAmountMinor > 0 else { return nil }
        return Double(amountMinor - previousAmountMinor) / Double(previousAmountMinor)
    }
}

struct MonthTotals: Identifiable, Equatable {
    let monthStart: Date
    let incomeMinor: Int64
    let expenseMinor: Int64
    var id: Date { monthStart }
}

struct CumulativePoint: Identifiable, Equatable {
    let day: Int
    let amountMinor: Int64
    var id: Int { day }
}

struct InsightsSnapshot: Equatable {
    var currency: CurrencyCode = .default
    var month = DateInterval()
    var incomeMinor: Int64 = 0
    var expenseMinor: Int64 = 0
    var previousExpenseMinor: Int64 = 0
    var dailySpend: [DailySpend] = []
    var averageDailyMinor: Int64 = 0
    var categories: [CategorySlice] = []
    var monthlyTotals: [MonthTotals] = []
    var cumulativeThisMonth: [CumulativePoint] = []
    var cumulativeLastMonth: [CumulativePoint] = []
    var transactionCount = 0

    var netMinor: Int64 { incomeMinor - expenseMinor }
    var hasData: Bool { transactionCount > 0 }
}

// Prepares everything the Insights screen draws: the month's totals, the daily
// breakdown, the category split, and six months of history.
@MainActor
@Observable
final class InsightsViewModel {
    private(set) var snapshot = InsightsSnapshot()
    private(set) var isLoaded = false
    var errorMessage: String?
    // Which month is on screen. The arrows at the top move this.
    private(set) var anchorDate: Date = .now

    private let container: AppContainer
    // Which colour each category gets, worked out once from the full list.
    //
    // Assigning colours by "biggest first" would be easier, but then a category's
    // colour would change from month to month, which makes comparing two months
    // quietly misleading.
    private var slotMap: [UUID: Int] = [:]

    init(container: AppContainer) {
        self.container = container
    }

    private var periods: PeriodCalculator { container.periods }
    private var calendar: Calendar { container.periods.calendar }

    var monthTitle: String {
        let isThisMonth = calendar.isDate(anchorDate, equalTo: .now, toGranularity: .month)
        return isThisMonth
            ? String(localized: "insights.thisMonth", defaultValue: "This month")
            : anchorDate.formatted(.dateTime.month(.wide).year())
    }

    var canStepForward: Bool {
        !calendar.isDate(anchorDate, equalTo: .now, toGranularity: .month)
    }

    func step(months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: anchorDate) else { return }
        anchorDate = min(next, .now)
        load()
    }

    func load() {
        do {
            let currency = container.currency.currentCurrency
            if slotMap.isEmpty {
                slotMap = ChartSlotAssignment.assign(try container.categories.categories(of: .expense, includeArchived: true))
            }
            let month = periods.month(containing: anchorDate)
            let previousMonth = periods.previous(.month, before: anchorDate)

            let monthTransactions = try container.transactions.transactions(matching: TransactionQuery(interval: month))
            let previousTransactions = try container.transactions.transactions(matching: TransactionQuery(interval: previousMonth))

            var snapshot = InsightsSnapshot()
            snapshot.currency = currency
            snapshot.month = month
            snapshot.transactionCount = monthTransactions.count

            let flow = BalanceCalculator.cashFlow(of: monthTransactions.map(\.ledgerLine))
            snapshot.incomeMinor = flow.incomeMinor
            snapshot.expenseMinor = flow.expenseMinor
            snapshot.previousExpenseMinor = BalanceCalculator.cashFlow(of: previousTransactions.map(\.ledgerLine)).expenseMinor

            snapshot.dailySpend = dailySpend(monthTransactions, in: month)
            let spendingDays = snapshot.dailySpend.filter { $0.amountMinor > 0 }.count
            snapshot.averageDailyMinor = spendingDays > 0 ? snapshot.expenseMinor / Int64(spendingDays) : 0

            snapshot.categories = categoryBreakdown(monthTransactions, previous: previousTransactions, total: flow.expenseMinor)
            snapshot.monthlyTotals = try monthlyHistory(endingAt: month, count: 6)
            snapshot.cumulativeThisMonth = cumulative(monthTransactions, in: month)
            snapshot.cumulativeLastMonth = cumulative(previousTransactions, in: previousMonth)

            self.snapshot = snapshot
            errorMessage = nil
            isLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            isLoaded = true
        }
    }

    // MARK: Copy

    // The sentence at the top. It says what changed before any chart is looked at.
    var headline: String {
        let snapshot = snapshot
        guard snapshot.hasData else {
            return String(localized: "insights.empty.headline", defaultValue: "Nothing recorded for this month yet.")
        }

        let spent = Money(minorUnits: snapshot.expenseMinor, currency: snapshot.currency)
        guard snapshot.previousExpenseMinor > 0 else {
            return String(localized: "insights.firstMonth", defaultValue: "\(spent.formatted()) spent across \(snapshot.transactionCount) entries.")
        }

        let change = Double(snapshot.expenseMinor - snapshot.previousExpenseMinor) / Double(snapshot.previousExpenseMinor)
        let percent = abs(change).formatted(.percent.precision(.fractionLength(0)))
        if abs(change) < 0.02 {
            return String(localized: "insights.steady", defaultValue: "\(spent.formatted()) spent — level with last month.")
        }
        let direction = change > 0
            ? String(localized: "insights.up", defaultValue: "up")
            : String(localized: "insights.down", defaultValue: "down")
        return String(localized: "insights.changed", defaultValue: "\(spent.formatted()) spent, \(percent) \(direction) on last month.")
    }

    var topCategoryLine: String? {
        guard let top = snapshot.categories.first, top.amountMinor > 0 else { return nil }
        let share = top.share.formatted(.percent.precision(.fractionLength(0)))
        return String(localized: "insights.topCategory", defaultValue: "\(top.name) took \(share) of everything you spent.")
    }

    // MARK: Building blocks

    private func dailySpend(_ transactions: [TransactionRecord], in month: DateInterval) -> [DailySpend] {
        var totals: [Date: Int64] = [:]
        for transaction in transactions where transaction.type == .expense {
            totals[calendar.startOfDay(for: transaction.date), default: 0] += transaction.amountMinor
        }
        return periods.days(in: month).map { DailySpend(date: $0, amountMinor: totals[$0] ?? 0) }
    }

    private func categoryBreakdown(
        _ transactions: [TransactionRecord],
        previous: [TransactionRecord],
        total: Int64
    ) -> [CategorySlice] {
        func totals(_ rows: [TransactionRecord]) -> [UUID: Int64] {
            rows.reduce(into: [:]) { result, row in
                guard row.type == .expense, let id = row.category?.id else { return }
                result[id, default: 0] += row.amountMinor
            }
        }

        let current = totals(transactions)
        let past = totals(previous)
        var descriptors: [UUID: TransactionCategory] = [:]
        for row in transactions {
            if let category = row.category { descriptors[category.id] = category }
        }

        return current
            .compactMap { id, amount -> CategorySlice? in
                guard let category = descriptors[id] else { return nil }
                return CategorySlice(
                    id: id,
                    name: category.name,
                    symbolName: category.symbolName,
                    slot: slotMap[id] ?? category.chartSlot,
                    amountMinor: amount,
                    previousAmountMinor: past[id] ?? 0,
                    share: total > 0 ? Double(amount) / Double(total) : 0
                )
            }
            .sorted { $0.amountMinor > $1.amountMinor }
    }

    private func monthlyHistory(endingAt month: DateInterval, count: Int) throws -> [MonthTotals] {
        var result: [MonthTotals] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let anchor = calendar.date(byAdding: .month, value: -offset, to: month.start) else { continue }
            let interval = periods.month(containing: anchor)
            let lines = try container.transactions.ledgerLines(in: interval)
            let flow = BalanceCalculator.cashFlow(of: lines)
            result.append(MonthTotals(
                monthStart: interval.start,
                incomeMinor: flow.incomeMinor,
                expenseMinor: flow.expenseMinor
            ))
        }
        return result
    }

    // A running total by day of the month, so two months can share one axis even
    // when one has 30 days and the other 31.
    private func cumulative(_ transactions: [TransactionRecord], in month: DateInterval) -> [CumulativePoint] {
        var byDay: [Int: Int64] = [:]
        for transaction in transactions where transaction.type == .expense {
            let day = calendar.component(.day, from: transaction.date)
            byDay[day, default: 0] += transaction.amountMinor
        }
        let dayCount = periods.days(in: month).count
        var running: Int64 = 0
        var points: [CumulativePoint] = []
        let lastDay = calendar.isDate(month.start, equalTo: .now, toGranularity: .month)
            ? calendar.component(.day, from: .now)
            : dayCount
        for day in 1...max(lastDay, 1) {
            running += byDay[day] ?? 0
            points.append(CumulativePoint(day: day, amountMinor: running))
        }
        return points
    }
}

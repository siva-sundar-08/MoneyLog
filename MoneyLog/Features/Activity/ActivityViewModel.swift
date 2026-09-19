import Foundation
import Observation

enum DateRangePreset: String, CaseIterable, Identifiable {
    case thisMonth, last30, last90, thisYear, all

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .thisMonth: String(localized: "range.thisMonth", defaultValue: "This month")
        case .last30: String(localized: "range.last30", defaultValue: "Last 30 days")
        case .last90: String(localized: "range.last90", defaultValue: "Last 90 days")
        case .thisYear: String(localized: "range.thisYear", defaultValue: "This year")
        case .all: String(localized: "range.all", defaultValue: "All time")
        }
    }

    func interval(now: Date, periods: PeriodCalculator) -> DateInterval? {
        let calendar = periods.calendar
        switch self {
        case .thisMonth:
            return periods.month(containing: now)
        case .last30, .last90:
            let days = self == .last30 ? -30 : -90
            guard let start = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) else { return nil }
            return DateInterval(start: start, end: calendar.startOfDay(for: now).addingTimeInterval(86_400))
        case .thisYear:
            return periods.interval(of: .year, containing: now)
        case .all:
            return nil
        }
    }
}

@MainActor
@Observable
final class ActivityViewModel {
    struct DaySection: Identifiable {
        let date: Date
        let transactions: [TransactionRecord]
        let netMinor: Int64
        var id: Date { date }
    }

    // A copy of what was deleted, kept just long enough for Undo to rebuild it.
    struct UndoEntry: Equatable {
        let draft: TransactionDraft
        let title: String
    }

    var searchText = ""
    var selectedTypes: Set<TransactionType> = []
    var selectedCategoryIDs: Set<UUID> = []
    var selectedAccountIDs: Set<UUID> = []
    var range: DateRangePreset = .last90

    private(set) var sections: [DaySection] = []
    private(set) var categories: [TransactionCategory] = []
    private(set) var accounts: [Account] = []
    private(set) var matchCount = 0
    private(set) var totals = CashFlowSummary()
    private(set) var isLoaded = false

    var errorMessage: String?
    var undoEntry: UndoEntry?

    private let container: AppContainer
    private var undoTask: Task<Void, Never>?
    private var reloadTask: Task<Void, Never>?

    init(container: AppContainer) {
        self.container = container
    }

    var currency: CurrencyCode { container.currency.currentCurrency }

    var hasActiveFilters: Bool {
        !selectedTypes.isEmpty || !selectedCategoryIDs.isEmpty || !selectedAccountIDs.isEmpty || range != .last90
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    func load(now: Date = .now) {
        do {
            if categories.isEmpty {
                categories = try container.categories.categories(of: nil, includeArchived: true)
            }
            if accounts.isEmpty {
                accounts = try container.accounts.accounts(includeArchived: true)
            }

            let query = TransactionQuery(
                interval: range.interval(now: now, periods: container.periods),
                types: selectedTypes,
                categoryIDs: selectedCategoryIDs,
                accountIDs: selectedAccountIDs,
                searchText: searchText
            )
            let results = try container.transactions.transactions(matching: query)
            matchCount = results.count
            totals = BalanceCalculator.cashFlow(of: results.map(\.ledgerLine))
            sections = Self.group(results, calendar: container.periods.calendar)
            errorMessage = nil
            isLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            isLoaded = true
        }
    }

    func clearFilters() {
        selectedTypes = []
        selectedCategoryIDs = []
        selectedAccountIDs = []
        range = .last90
        searchText = ""
        load()
    }

    func toggle(type: TransactionType) {
        if selectedTypes.contains(type) { selectedTypes.remove(type) } else { selectedTypes.insert(type) }
        load()
    }

    func toggle(categoryID: UUID) {
        if selectedCategoryIDs.contains(categoryID) { selectedCategoryIDs.remove(categoryID) } else { selectedCategoryIDs.insert(categoryID) }
        load()
    }

    func toggle(accountID: UUID) {
        if selectedAccountIDs.contains(accountID) { selectedAccountIDs.remove(accountID) } else { selectedAccountIDs.insert(accountID) }
        load()
    }

    func select(range newRange: DateRangePreset) {
        range = newRange
        load()
    }

    // MARK: Delete with undo

    // Deletes immediately and shows an Undo button for five seconds.
    //
    // The alternative — "Are you sure?" every time — punishes the many correct
    // deletions to protect against the rare wrong one. Undo does the same job
    // without the interruption.
    func delete(_ transaction: TransactionRecord) {
        let snapshot = TransactionDraft(
            amount: transaction.amount,
            type: transaction.type,
            date: transaction.date,
            accountID: transaction.account?.id,
            destinationAccountID: transaction.destinationAccount?.id,
            categoryID: transaction.category?.id,
            merchant: transaction.merchant ?? "",
            note: transaction.note ?? ""
        )
        let title = transaction.displayTitle
        do {
            try container.transactions.delete(transaction)
            Haptics.play(.deleted)
            undoEntry = UndoEntry(draft: snapshot, title: title)
            scheduleUndoExpiry()
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undoDelete() {
        guard let entry = undoEntry else { return }
        undoTask?.cancel()
        undoEntry = nil
        do {
            try container.transactions.create(entry.draft)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissUndo() {
        undoTask?.cancel()
        undoEntry = nil
    }

    private func scheduleUndoExpiry() {
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.undoEntry = nil
        }
    }

    // Waits 180ms after the last keystroke before searching.
    //
    // Otherwise typing "swiggy" runs six searches, five of which nobody wanted.
    func searchTextChanged() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self?.load()
        }
    }

    private static func group(_ transactions: [TransactionRecord], calendar: Calendar) -> [DaySection] {
        let grouped = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            let rows = (grouped[day] ?? []).sorted { $0.date > $1.date }
            let net = rows.reduce(Int64(0)) { total, row in
                switch row.type {
                case .income: total + row.amountMinor
                case .expense: total - row.amountMinor
                case .transfer: total
                }
            }
            return DaySection(date: day, transactions: rows, netMinor: net)
        }
    }
}

import SwiftUI

// The full history: search, filters, and every transaction grouped by day.
struct ActivityView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var model: ActivityViewModel?
    @State private var editingTransaction: TransactionRecord?

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                if let model {
                    content(model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(Text("Activity"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
        }
        .task {
            if model == nil { model = ActivityViewModel(container: container) }
            model?.load()
        }
        .onChange(of: router.dataVersion) { _, _ in model?.load() }
        .sheet(item: $editingTransaction) { transaction in
            AddTransactionView(editing: transaction)
                .environment(container)
                .environment(router)
        }
    }

    @ViewBuilder
    private func content(_ model: ActivityViewModel) -> some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            FilterBar(model: model)

            if model.sections.isEmpty {
                emptyState(model)
            } else {
                List {
                    SummaryRow(totals: model.totals, currency: model.currency, count: model.matchCount)

                    ForEach(model.sections) { section in
                        Section {
                            ForEach(section.transactions) { transaction in
                                Button {
                                    editingTransaction = transaction
                                } label: {
                                    TransactionRow(transaction: transaction)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Palette.surface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation(Motion.layout) { model.delete(transaction) }
                                    } label: {
                                        Label(String(localized: "action.delete", defaultValue: "Delete"), systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        editingTransaction = transaction
                                    } label: {
                                        Label(String(localized: "action.edit", defaultValue: "Edit"), systemImage: "pencil")
                                    }
                                    .tint(Palette.accent)
                                }
                            }
                        } header: {
                            DayHeader(date: section.date, netMinor: section.netMinor, currency: model.currency)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .animation(Motion.layout, value: model.matchCount)
            }
        }
        .searchable(
            text: $model.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Search merchant, note or amount")
        )
        .onChange(of: model.searchText) { _, _ in model.searchTextChanged() }
        .overlay(alignment: .bottom) {
            if let entry = model.undoEntry {
                UndoToast(title: entry.title) { model.undoDelete() }
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.bottom, Spacing.l)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.layout, value: model.undoEntry)
    }

    @ViewBuilder
    private func emptyState(_ model: ActivityViewModel) -> some View {
        ScrollView {
            if model.isSearching {
                EmptyState(
                    symbolName: "magnifyingglass",
                    title: String(localized: "empty.search.title", defaultValue: "No matches"),
                    message: String(localized: "empty.search.message", defaultValue: "Nothing here matches “\(model.searchText)”. Try a different word, or widen the filters."),
                    actionTitle: String(localized: "action.clearFilters", defaultValue: "Clear filters"),
                    action: { model.clearFilters() }
                )
            } else if model.hasActiveFilters {
                EmptyState(
                    symbolName: "line.3.horizontal.decrease",
                    title: String(localized: "empty.filtered.title", defaultValue: "Nothing in this slice"),
                    message: String(localized: "empty.filtered.message", defaultValue: "No transactions match these filters."),
                    actionTitle: String(localized: "action.clearFilters", defaultValue: "Clear filters"),
                    action: { model.clearFilters() }
                )
            } else {
                EmptyState(
                    symbolName: "tray",
                    title: String(localized: "empty.activity.title", defaultValue: "No history yet"),
                    message: String(localized: "empty.activity.message", defaultValue: "Every expense and income you record shows up here, grouped by day."),
                    actionTitle: String(localized: "action.addFirst", defaultValue: "Add an expense"),
                    action: { router.isPresentingAdd = true }
                )
            }
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - Filter bar

private struct FilterBar: View {
    @Bindable var model: ActivityViewModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                Menu {
                    Picker(String(localized: "filter.range", defaultValue: "Period"), selection: Binding(
                        get: { model.range },
                        set: { model.select(range: $0) }
                    )) {
                        ForEach(DateRangePreset.allCases) { preset in
                            Text(preset.localizedName).tag(preset)
                        }
                    }
                } label: {
                    FilterChip(title: model.range.localizedName, isActive: model.range != .last90, systemImage: "calendar")
                }

                Menu {
                    ForEach(TransactionType.allCases) { type in
                        Toggle(type.localizedName, isOn: Binding(
                            get: { model.selectedTypes.contains(type) },
                            set: { _ in model.toggle(type: type) }
                        ))
                    }
                } label: {
                    FilterChip(
                        title: typeTitle,
                        isActive: !model.selectedTypes.isEmpty,
                        systemImage: "arrow.left.arrow.right"
                    )
                }

                Menu {
                    ForEach(model.categories) { category in
                        Toggle(isOn: Binding(
                            get: { model.selectedCategoryIDs.contains(category.id) },
                            set: { _ in model.toggle(categoryID: category.id) }
                        )) {
                            Label(category.name, systemImage: category.symbolName)
                        }
                    }
                } label: {
                    FilterChip(
                        title: countTitle(String(localized: "filter.category", defaultValue: "Category"), model.selectedCategoryIDs.count),
                        isActive: !model.selectedCategoryIDs.isEmpty,
                        systemImage: "square.grid.2x2"
                    )
                }

                Menu {
                    ForEach(model.accounts) { account in
                        Toggle(isOn: Binding(
                            get: { model.selectedAccountIDs.contains(account.id) },
                            set: { _ in model.toggle(accountID: account.id) }
                        )) {
                            Label(account.name, systemImage: account.type.symbolName)
                        }
                    }
                } label: {
                    FilterChip(
                        title: countTitle(String(localized: "filter.account", defaultValue: "Account"), model.selectedAccountIDs.count),
                        isActive: !model.selectedAccountIDs.isEmpty,
                        systemImage: "wallet.bifold"
                    )
                }

                if model.hasActiveFilters {
                    Button {
                        withAnimation(Motion.layout) { model.clearFilters() }
                    } label: {
                        Label(String(localized: "action.clear", defaultValue: "Clear"), systemImage: "xmark")
                            .labelStyle(.iconOnly)
                            .font(Typography.caption)
                            .padding(Spacing.xs)
                            .background(Palette.surfaceSunken)
                            .clipShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.xs)
        }
        .scrollIndicators(.hidden)
        .background(Palette.canvas)
    }

    private var typeTitle: String {
        if model.selectedTypes.count == 1, let type = model.selectedTypes.first { return type.localizedName }
        return countTitle(String(localized: "filter.type", defaultValue: "Type"), model.selectedTypes.count)
    }

    private func countTitle(_ base: String, _ count: Int) -> String {
        count == 0 ? base : "\(base) (\(count))"
    }
}

private struct FilterChip: View {
    let title: String
    let isActive: Bool
    let systemImage: String

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
            Text(title)
                .font(Typography.caption.weight(.medium))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(isActive ? Palette.accent : Palette.inkSecondary)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .background(isActive ? Palette.accentSoft : Palette.surface)
        .clipShape(.capsule)
        .overlay {
            Capsule().strokeBorder(isActive ? Palette.accent.opacity(0.35) : Palette.hairline, lineWidth: 0.5)
        }
    }
}

// MARK: - Rows

private struct SummaryRow: View {
    let totals: CashFlowSummary
    let currency: CurrencyCode
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.m) {
            column(String(localized: "activity.in", defaultValue: "In"), Money(minorUnits: totals.incomeMinor, currency: currency), Palette.income)
            Divider().frame(height: 28)
            column(String(localized: "activity.out", defaultValue: "Out"), Money(minorUnits: totals.expenseMinor, currency: currency), Palette.ink)
            Divider().frame(height: 28)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                MicroLabel(String(localized: "activity.entries", defaultValue: "Entries"))
                Text(count.formatted())
                    .font(Typography.amountTitle)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.xs)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
    }

    private func column(_ label: String, _ money: Money, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            MicroLabel(label)
            AmountText(money: money, size: .title, color: color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DayHeader: View {
    let date: Date
    let netMinor: Int64
    let currency: CurrencyCode

    var body: some View {
        HStack {
            Text(title)
                .font(Typography.insightSerif)
                .foregroundStyle(Palette.ink)
            Spacer()
            AmountText(
                money: Money(minorUnits: netMinor, currency: currency),
                size: .caption,
                color: netMinor < 0 ? Palette.inkTertiary : Palette.income,
                showsPlusSign: netMinor > 0
            )
        }
        .textCase(nil)
        .padding(.vertical, Spacing.xxs)
    }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "date.today", defaultValue: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "date.yesterday", defaultValue: "Yesterday") }
        if let year = calendar.dateComponents([.year], from: date).year,
           year != calendar.component(.year, from: .now) {
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
    }
}

private struct UndoToast: View {
    let title: String
    let undo: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: Spacing.s) {
            Text(String(localized: "undo.deleted", defaultValue: "Deleted “\(title)”"))
                .font(Typography.caption)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)

            Spacer(minLength: Spacing.xs)

            Button(String(localized: "action.undo", defaultValue: "Undo"), action: undo)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(Palette.accent)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(Palette.surfaceRaised)
        .clipShape(.capsule)
        .overlay { Capsule().strokeBorder(Palette.hairline, lineWidth: 0.5) }
        .shadow(color: .black.opacity(Elevation.shadowOpacity(for: scheme, floating: true)), radius: 12, y: 4)
    }
}

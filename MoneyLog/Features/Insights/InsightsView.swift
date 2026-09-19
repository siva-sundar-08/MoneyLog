import SwiftUI

// The analytics screen: one month at a time, with charts underneath a plain-English
// summary of what changed.
struct InsightsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model: InsightsViewModel?
    @State private var selectedCategoryID: UUID?
    @State private var chartProgress: Double = 0

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
            .navigationTitle(Text("Insights"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
        }
        .task {
            if model == nil { model = InsightsViewModel(container: container) }
            model?.load()
            animateCharts()
        }
        .onChange(of: router.dataVersion) { _, _ in model?.load() }
    }

    @ViewBuilder
    private func content(_ model: InsightsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                MonthStepper(
                    title: model.monthTitle,
                    canStepForward: model.canStepForward,
                    onBack: { step(model, -1) },
                    onForward: { step(model, 1) }
                )
                .reveal(0)

                if model.snapshot.hasData {
                    headline(model)
                        .reveal(1)

                    ChartCard(
                        title: String(localized: "insights.daily", defaultValue: "Spending by day"),
                        height: 150
                    ) {
                        DailySpendChart(
                            days: model.snapshot.dailySpend,
                            averageMinor: model.snapshot.averageDailyMinor,
                            currency: model.snapshot.currency,
                            progress: chartProgress
                        )
                    }
                    .reveal(2)

                    categoryCard(model)
                        .reveal(3)

                    ChartCard(
                        title: String(localized: "insights.inOut", defaultValue: "In and out"),
                        caption: nil,
                        height: 160
                    ) {
                        IncomeExpenseChart(
                            months: model.snapshot.monthlyTotals,
                            currency: model.snapshot.currency,
                            progress: chartProgress
                        )
                    } legend: {
                        ChartLegend(items: [
                            .init(
                                label: String(localized: "insights.in", defaultValue: "In"),
                                color: ChartPalette.incomeSeries,
                                value: Money(minorUnits: model.snapshot.incomeMinor, currency: model.snapshot.currency).formatted()
                            ),
                            .init(
                                label: String(localized: "insights.out", defaultValue: "Out"),
                                color: ChartPalette.expenseSeries,
                                value: Money(minorUnits: model.snapshot.expenseMinor, currency: model.snapshot.currency).formatted()
                            ),
                        ])
                    }
                    .reveal(4)

                    ChartCard(
                        title: String(localized: "insights.pace", defaultValue: "Against last month"),
                        height: 150
                    ) {
                        CumulativeComparisonChart(
                            thisMonth: model.snapshot.cumulativeThisMonth,
                            lastMonth: model.snapshot.cumulativeLastMonth,
                            currency: model.snapshot.currency,
                            progress: chartProgress
                        )
                    } legend: {
                        ChartLegend(items: [
                            .init(label: model.monthTitle, color: Palette.accent),
                            .init(label: String(localized: "insights.lastMonth", defaultValue: "Last month"), color: ChartPalette.comparison),
                        ])
                    }
                    .reveal(5)

                    TopCategoriesCard(
                        slices: Array(model.snapshot.categories.prefix(5)),
                        currency: model.snapshot.currency
                    )
                    .reveal(6)
                } else {
                    EmptyState(
                        symbolName: "chart.line.uptrend.xyaxis",
                        title: String(localized: "empty.insights.title", defaultValue: "Nothing to chart yet"),
                        message: String(localized: "empty.insights.message", defaultValue: "Record a few expenses and this fills with your patterns — by day, by category, against last month."),
                        actionTitle: String(localized: "action.addFirst", defaultValue: "Add an expense"),
                        action: { router.isPresentingAdd = true }
                    )
                    .padding(.top, Spacing.xl)
                }

                if let errorMessage = model.errorMessage {
                    InlineErrorBanner(message: errorMessage)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private func headline(_ model: InsightsViewModel) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(model.headline)
                    .font(Typography.insightSerif)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let line = model.topCategoryLine {
                    Text(line)
                        .font(Typography.callout)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func categoryCard(_ model: InsightsViewModel) -> some View {
        ChartCard(
            title: String(localized: "insights.byCategory", defaultValue: "Where it went"),
            height: 190
        ) {
            CategoryDonutChart(
                slices: model.snapshot.categories,
                currency: model.snapshot.currency,
                totalMinor: model.snapshot.expenseMinor,
                progress: chartProgress,
                selectedID: $selectedCategoryID
            )
        } legend: {
            ChartLegend(
                items: model.snapshot.categories.prefix(6).map { slice in
                    ChartLegend.Item(
                        label: slice.name,
                        color: ChartPalette.color(slot: slice.slot),
                        value: slice.share.formatted(.percent.precision(.fractionLength(0)))
                    )
                }
            )
        }
    }

    private func step(_ model: InsightsViewModel, _ months: Int) {
        selectedCategoryID = nil
        chartProgress = reduceMotion ? 1 : 0
        model.step(months: months)
        animateCharts()
    }

    // Charts animate in by multiplying their values by a number that goes 0 → 1.
    //
    // The obvious approach — animating the whole chart view — also animates the
    // axis labels, which slide around and look broken. Scaling the data only grows
    // the bars.
    private func animateCharts() {
        guard !reduceMotion else {
            chartProgress = 1
            return
        }
        chartProgress = 0
        withAnimation(Motion.reveal.delay(0.05)) { chartProgress = 1 }
    }
}

// MARK: - Month stepper

private struct MonthStepper: View {
    let title: String
    let canStepForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Palette.surface)
                    .clipShape(.circle)
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: 0.5) }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(Text("Previous month"))

            Spacer()

            Text(title)
                .font(Typography.titleSerif)
                .foregroundStyle(Palette.ink)
                .contentTransition(.opacity)

            Spacer()

            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Palette.surface)
                    .clipShape(.circle)
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: 0.5) }
            }
            .buttonStyle(PressableStyle())
            .disabled(!canStepForward)
            .opacity(canStepForward ? 1 : 0.35)
            .accessibilityLabel(Text("Next month"))
        }
        .foregroundStyle(Palette.ink)
        .padding(.top, Spacing.xs)
    }
}

// MARK: - Top categories

private struct TopCategoriesCard: View {
    let slices: [CategorySlice]
    let currency: CurrencyCode

    private var peak: Int64 { max(slices.first?.amountMinor ?? 1, 1) }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                MicroLabel(String(localized: "insights.top", defaultValue: "Top categories"))

                ForEach(slices) { slice in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: slice.symbolName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ChartPalette.color(slot: slice.slot))
                                .frame(width: 18)

                            Text(slice.name)
                                .font(Typography.callout)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)

                            Spacer(minLength: Spacing.xs)

                            if let change = slice.change, abs(change) >= 0.05 {
                                ChangeBadge(change: change)
                            }

                            AmountText(money: Money(minorUnits: slice.amountMinor, currency: currency), size: .body)
                        }

                        GeometryReader { proxy in
                            Capsule()
                                .fill(ChartPalette.color(slot: slice.slot).opacity(0.85))
                                .frame(width: max(proxy.size.width * (Double(slice.amountMinor) / Double(peak)), 4))
                        }
                        .frame(height: 4)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct ChangeBadge: View {
    let change: Double

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text(abs(change).formatted(.percent.precision(.fractionLength(0))))
                .font(Typography.micro)
                .monospacedDigit()
        }
        // Rising spending isn't automatically bad, so this stays informational, not alarming.
        .foregroundStyle(Palette.inkTertiary)
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, 1)
        .background(Palette.surfaceSunken)
        .clipShape(.capsule)
        .accessibilityLabel(Text(change > 0 ? "Up \(abs(change).formatted(.percent.precision(.fractionLength(0))))" : "Down \(abs(change).formatted(.percent.precision(.fractionLength(0))))"))
    }
}

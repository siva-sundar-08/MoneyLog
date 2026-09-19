import SwiftUI
import Charts

// Shared bits every chart needs: converting paise to rupees for plotting, and
// picking axis numbers a person would actually say out loud.
enum ChartScale {
    // Charts plot in rupees, not paise. This is the one place we convert to a
    // Double — fine for drawing a bar, never for storing a value.
    static func value(_ minorUnits: Int64, _ currency: CurrencyCode) -> Double {
        Double(minorUnits) / Double(currency.minorUnitScale)
    }

    // Three axis labels, rounded to a friendly number. More than three is clutter.
    static func yTicks(max value: Double) -> [Double] {
        guard value > 0 else { return [0] }
        let magnitude = pow(10, floor(log10(value)))
        let step = (value / 2 / magnitude).rounded(.up) * magnitude
        return [0, step, step * 2]
    }
}

// MARK: - Spending by day

struct DailySpendChart: View {
    let days: [DailySpend]
    let averageMinor: Int64
    let currency: CurrencyCode
    let progress: Double

    @State private var selectedDate: Date?

    private var maxValue: Double {
        ChartScale.value(days.map(\.amountMinor).max() ?? 0, currency)
    }

    private var selectedDay: DailySpend? {
        guard let selectedDate else { return nil }
        return days.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Spent", ChartScale.value(day.amountMinor, currency) * progress),
                    width: .fixed(5)
                )
                .clipShape(.rect(cornerRadius: 2.5, style: .continuous))
                .foregroundStyle(barColor(for: day))
            }

            if averageMinor > 0 {
                RuleMark(y: .value("Average", ChartScale.value(averageMinor, currency)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Palette.inkTertiary)
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Text(String(localized: "chart.average", defaultValue: "avg \(Money(minorUnits: averageMinor, currency: currency).formatted())"))
                            .font(Typography.micro)
                            .foregroundStyle(Palette.inkTertiary)
                    }
            }

            if let selectedDay {
                RuleMark(x: .value("Day", selectedDay.date, unit: .day))
                    .foregroundStyle(Palette.ink.opacity(0.15))
                    .annotation(position: .top, alignment: .center, overflowResolution: .init(x: .fit, y: .disabled)) {
                        ChartReadout(
                            title: selectedDay.date.formatted(.dateTime.day().month(.abbreviated)),
                            value: Money(minorUnits: selectedDay.amountMinor, currency: currency).formatted()
                        )
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: 0...(max(maxValue, 1) * 1.15))
        .moneyLogChartAxes(yValues: ChartScale.yTicks(max: maxValue))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisValueLabel(format: .dateTime.day(), centered: false)
                    .font(Typography.micro)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }

    private func barColor(for day: DailySpend) -> Color {
        if let selectedDay, selectedDay.id == day.id { return Palette.accent }
        return day.amountMinor > 0 ? Palette.accent.opacity(0.55) : Palette.surfaceSunken
    }
}

// MARK: - Income vs expense

struct IncomeExpenseChart: View {
    let months: [MonthTotals]
    let currency: CurrencyCode
    let progress: Double

    private var maxValue: Double {
        ChartScale.value(months.flatMap { [$0.incomeMinor, $0.expenseMinor] }.max() ?? 0, currency)
    }

    var body: some View {
        Chart {
            ForEach(months) { month in
                BarMark(
                    x: .value("Month", month.monthStart, unit: .month),
                    y: .value("Amount", ChartScale.value(month.incomeMinor, currency) * progress),
                    width: .fixed(14)
                )
                .position(by: .value("Series", "In"), axis: .horizontal, span: .ratio(0.7))
                .clipShape(.rect(cornerRadius: 4, style: .continuous))
                .foregroundStyle(by: .value("Series", "In"))

                BarMark(
                    x: .value("Month", month.monthStart, unit: .month),
                    y: .value("Amount", ChartScale.value(month.expenseMinor, currency) * progress),
                    width: .fixed(14)
                )
                .position(by: .value("Series", "Out"), axis: .horizontal, span: .ratio(0.7))
                .clipShape(.rect(cornerRadius: 4, style: .continuous))
                .foregroundStyle(by: .value("Series", "Out"))
            }
        }
        .chartForegroundStyleScale([
            "In": ChartPalette.incomeSeries,
            "Out": ChartPalette.expenseSeries,
        ])
        .chartLegend(.hidden)
        .chartYScale(domain: 0...(max(maxValue, 1) * 1.15))
        .moneyLogChartAxes(yValues: ChartScale.yTicks(max: maxValue))
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisValueLabel(format: .dateTime.month(.narrow))
                    .font(Typography.micro)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }
}

// MARK: - Category donut

struct CategoryDonutChart: View {
    let slices: [CategorySlice]
    let currency: CurrencyCode
    let totalMinor: Int64
    let progress: Double
    @Binding var selectedID: UUID?

    @State private var selectedAngle: Double?

    private var displayed: [CategorySlice] {
        // Nine or more series is never nine hues: the tail folds into "Other".
        guard slices.count > ChartPalette.slotCount else { return slices }
        let head = Array(slices.prefix(ChartPalette.slotCount - 1))
        let tailTotal = slices.dropFirst(ChartPalette.slotCount - 1).reduce(Int64(0)) { $0 + $1.amountMinor }
        let other = CategorySlice(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000FF") ?? UUID(),
            name: String(localized: "chart.other", defaultValue: "Other"),
            symbolName: "ellipsis",
            slot: ChartPalette.slotCount - 1,
            amountMinor: tailTotal,
            previousAmountMinor: 0,
            share: totalMinor > 0 ? Double(tailTotal) / Double(totalMinor) : 0
        )
        return head + [other]
    }

    private var focused: CategorySlice? {
        displayed.first { $0.id == selectedID }
    }

    var body: some View {
        Chart(displayed) { slice in
            SectorMark(
                angle: .value("Amount", Double(slice.amountMinor) * progress),
                innerRadius: .ratio(0.66),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(ChartPalette.color(slot: slice.slot))
            .opacity(selectedID == nil || selectedID == slice.id ? 1 : 0.35)
        }
        .chartAngleSelection(value: $selectedAngle)
        .chartBackground { _ in
            VStack(spacing: 2) {
                if let focused {
                    Text(focused.name)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                    AmountText(money: Money(minorUnits: focused.amountMinor, currency: currency), size: .title)
                    Text(focused.share.formatted(.percent.precision(.fractionLength(0))))
                        .font(Typography.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                } else {
                    MicroLabel(String(localized: "chart.total", defaultValue: "Total"))
                    AmountText(money: Money(minorUnits: totalMinor, currency: currency), size: .title)
                }
            }
            .padding(Spacing.s)
        }
        .onChange(of: selectedAngle) { _, angle in
            withAnimation(Motion.select) { selectedID = sliceID(atAngle: angle) }
        }
    }

    // Turns the tapped angle into a slice.
    //
    // Charts tells us the angle that was tapped, not which slice it belongs to, so
    // we add up the slices until we pass that angle.
    private func sliceID(atAngle angle: Double?) -> UUID? {
        guard let angle else { return nil }
        var running = 0.0
        for slice in displayed {
            running += Double(slice.amountMinor)
            if angle <= running { return slice.id }
        }
        return nil
    }
}

// MARK: - Month over month

struct CumulativeComparisonChart: View {
    let thisMonth: [CumulativePoint]
    let lastMonth: [CumulativePoint]
    let currency: CurrencyCode
    let progress: Double

    private var maxValue: Double {
        ChartScale.value(max(thisMonth.last?.amountMinor ?? 0, lastMonth.last?.amountMinor ?? 0), currency)
    }

    var body: some View {
        Chart {
            ForEach(lastMonth) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Spent", ChartScale.value(point.amountMinor, currency) * progress),
                    series: .value("Series", "Last month")
                )
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                .foregroundStyle(ChartPalette.comparison)
            }

            ForEach(thisMonth) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Spent", ChartScale.value(point.amountMinor, currency) * progress),
                    series: .value("Series", "This month")
                )
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .foregroundStyle(Palette.accent)
                .interpolationMethod(.monotone)
            }

            if let last = thisMonth.last {
                PointMark(
                    x: .value("Day", last.day),
                    y: .value("Spent", ChartScale.value(last.amountMinor, currency) * progress)
                )
                .symbolSize(60)
                .foregroundStyle(Palette.accent)
            }
        }
        .chartYScale(domain: 0...(max(maxValue, 1) * 1.15))
        .moneyLogChartAxes(yValues: ChartScale.yTicks(max: maxValue))
        .chartXAxis {
            AxisMarks(values: [1, 10, 20, 30]) { value in
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        Text(day.formatted())
                            .font(Typography.micro)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Readout

struct ChartReadout: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(Typography.micro)
                .foregroundStyle(Palette.inkTertiary)
            Text(value)
                .font(Typography.amountCaption)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(Palette.surfaceRaised)
        .cardShape(8)
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.5) }
    }
}

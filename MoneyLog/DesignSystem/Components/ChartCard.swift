import SwiftUI
import Charts

// The frame around every chart: title on top, the chart itself, a legend below.
//
// The charts only draw data; this handles everything around them. That's why they
// all sit at the same height with the same title style.
struct ChartCard<Content: View, Legend: View>: View {
    let title: String
    var caption: String? = nil
    var height: CGFloat = 180
    @ViewBuilder var content: Content
    @ViewBuilder var legend: Legend

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    MicroLabel(title)
                    if let caption {
                        Text(caption)
                            .font(Typography.insightSerif)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                content
                    .frame(height: height)

                legend
            }
        }
    }
}

extension ChartCard where Legend == EmptyView {
    init(title: String, caption: String? = nil, height: CGFloat = 180, @ViewBuilder content: () -> Content) {
        self.init(title: title, caption: caption, height: height, content: content) { EmptyView() }
    }
}

// The little colour swatches with names underneath a chart.
//
// Always present when there's more than one colour, because a chart that relies on
// colour alone is unreadable to anyone who can't tell those colours apart.
struct ChartLegend: View {
    struct Item: Identifiable {
        let id: String
        let label: String
        let color: Color
        var value: String?

        init(label: String, color: Color, value: String? = nil) {
            self.id = label
            self.label = label
            self.color = color
            self.value = value
        }
    }

    let items: [Item]
    var columns = 2

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: columns),
            alignment: .leading,
            spacing: Spacing.xxs
        ) {
            ForEach(items) { item in
                HStack(spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(item.color)
                        .frame(width: 10, height: 10)

                    Text(item.label)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)

                    if let value = item.value {
                        Spacer(minLength: Spacing.xxs)
                        Text(value)
                            .font(Typography.amountCaption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// One axis style for every chart: hairline grid, three labels at most, grey text.
// Charts should show data, not scaffolding.
extension View {
    func moneyLogChartAxes(yValues: [Double]) -> some View {
        self
            .chartYAxis {
                AxisMarks(position: .leading, values: yValues) { value in
                    AxisGridLine().foregroundStyle(Palette.hairline)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(CompactAxisFormatter.string(amount))
                                .font(Typography.micro)
                                .monospacedDigit()
                                .foregroundStyle(Palette.inkTertiary)
                        }
                    }
                }
            }
    }
}

enum CompactAxisFormatter {
    // Keeps axis labels short: ₹1.2L rather than ₹1,20,000.
    static func string(_ majorUnits: Double, locale: Locale = .current) -> String {
        majorUnits.formatted(.number.notation(.compactName).precision(.significantDigits(1...2)).locale(locale))
    }
}

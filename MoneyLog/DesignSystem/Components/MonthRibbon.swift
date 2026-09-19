import SwiftUI

struct DailySpend: Identifiable, Equatable {
    let date: Date
    let amountMinor: Int64
    var id: Date { date }
}

// One thin bar per day of the month, showing what you spent each day.
//
// This is the app's signature shape — the thing you'd recognise in a screenshot.
// Days with no spending stay as a faint line so the row still reads as a calendar,
// and today's bar is drawn in the accent colour.
struct MonthRibbon: View {
    let days: [DailySpend]
    let currency: CurrencyCode
    var height: CGFloat = 46
    var todayIndex: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAnimated = false

    private var peak: Int64 { max(days.map(\.amountMinor).max() ?? 0, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                let fraction = Double(day.amountMinor) / Double(peak)
                let isToday = index == todayIndex

                Capsule()
                    .fill(isToday ? Palette.accent : (day.amountMinor > 0 ? Palette.accent.opacity(0.35) : Palette.surfaceSunken))
                    .frame(height: barHeight(fraction: fraction))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height, alignment: .bottom)
        .onAppear {
            guard !hasAnimated else { return }
            if reduceMotion {
                hasAnimated = true
            } else {
                withAnimation(Motion.reveal) { hasAnimated = true }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Daily spending this month"))
        .accessibilityValue(accessibilityValue)
    }

    private func barHeight(fraction: Double) -> CGFloat {
        let minimum: CGFloat = 3
        guard hasAnimated else { return minimum }
        return max(minimum, height * CGFloat(min(max(fraction, 0), 1)))
    }

    private var accessibilityValue: String {
        let total = days.reduce(Int64(0)) { $0 + $1.amountMinor }
        let busiest = days.max { $0.amountMinor < $1.amountMinor }
        let totalText = MoneyFormatter.string(Money(minorUnits: total, currency: currency))
        guard let busiest, busiest.amountMinor > 0 else { return totalText }
        let dayText = busiest.date.formatted(.dateTime.day().month(.wide))
        let amountText = MoneyFormatter.string(Money(minorUnits: busiest.amountMinor, currency: currency))
        return "\(totalText). Highest on \(dayText), \(amountText)."
    }
}

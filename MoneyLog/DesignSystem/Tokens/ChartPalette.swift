import SwiftUI

// The eight colours charts use for their bars and slices.
//
// Why not reuse the category colours? Those are tuned to sit quietly behind a
// small symbol. When we measured them as chart colours, several pairs were
// indistinguishable to colour-blind viewers — fine as a faint background, useless
// as "this slice versus that slice".
//
// So these eight were checked against the usual tests: are they far enough apart
// for the common forms of colour blindness, and do they show up against the card
// behind them. Dark mode gets its own eight rather than a lightened copy, because
// simply brightening a colour tends to wash it out.
//
// Each category keeps the same colour whatever month you're looking at. If we
// handed out colours by size — biggest slice gets the first colour — then Food
// would be teal one month and orange the next, and comparing two months would
// quietly mislead you.
enum ChartPalette {
    static let slotCount = 8

    private static let light: [UInt32] = [
        0x7E5D00, 0x16999B, 0x82467D, 0x69B76D, 0x8C3C31, 0x74AEE9, 0x526B12, 0xE68C9A,
    ]

    private static let dark: [UInt32] = [
        0x896600, 0x06A4A5, 0x8E4D89, 0x5FA362, 0xA74638, 0x5893CF, 0x577214, 0xC67481,
    ]

    static func color(slot: Int) -> Color {
        let index = ((slot % slotCount) + slotCount) % slotCount
        return Palette.dynamic(light: light[index], dark: dark[index])
    }

    // "In" and "Out" are a pair, not categories, so they get their own colours.
    //
    // They were green and teal at first, which measured too close together to tell
    // apart at a glance. Expense is now ink, which also fits the rule that spending
    // isn't something to be alarmed about.
    static let incomeSeries = Palette.income
    static let expenseSeries = Palette.ink.opacity(0.82)
    // Last month's line, deliberately faint so this month reads first.
    static let comparison = Palette.inkTertiary
}

extension TintKey {
    // Picks the chart colour closest to the category's own tint.
    //
    // So a category that's terracotta in the list is a similar warm colour in a
    // chart — recognisably the same thing — without using the exact tint, which is
    // too soft to tell apart when it's a bar next to another bar.
    var preferredChartSlot: Int {
        switch self {
        case .ochre, .sand: 0   // ochre
        case .teal: 1           // teal
        case .plum: 2           // plum
        case .sage: 3           // green
        case .terracotta: 4     // clay
        case .slate, .indigo: 5 // blue
        case .moss: 6           // olive
        case .rose: 7           // rose
        }
    }
}

// Hands out a colour to every category, once, from the full list.
//
// Two categories can prefer the same colour; when they clash the second one takes
// the next free slot. Because it runs over every category in a fixed order, the
// result is the same every time — which is what keeps colours stable between months.
enum ChartSlotAssignment {
    static func assign(_ categories: [TransactionCategory]) -> [UUID: Int] {
        var assigned: [UUID: Int] = [:]
        var used: Set<Int> = []

        for category in categories.sorted(by: { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }) {
            var slot = category.tint.preferredChartSlot
            var attempts = 0
            while used.contains(slot), attempts < ChartPalette.slotCount {
                slot = (slot + 1) % ChartPalette.slotCount
                attempts += 1
            }
            assigned[category.id] = slot
            used.insert(slot)
            // Past eight categories the palette starts again rather than inventing hues.
            if used.count == ChartPalette.slotCount { used.removeAll() }
        }
        return assigned
    }
}

extension TransactionCategory {
    // Used when we don't have the full assignment to hand — good enough for one glyph.
    var chartSlot: Int { tint.preferredChartSlot }

    var chartColor: Color { ChartPalette.color(slot: chartSlot) }
}

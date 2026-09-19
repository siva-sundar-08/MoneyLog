import SwiftUI

// Every font choice in the app.
//
// Two voices on purpose. A serif (New York) for headlines and the one-line
// summaries, which gives the app a quieter, more editorial feel than the usual
// all-bold finance look. And rounded digits for money.
//
// Money uses "monospaced digits", meaning every number is the same width. That's
// why columns of amounts line up, and why a changing total doesn't make the text
// jiggle. All of it scales when the user picks a bigger text size in iOS.
enum Typography {
    // Editorial
    static let displaySerif = Font.system(.largeTitle, design: .serif, weight: .regular)
    static let titleSerif = Font.system(.title2, design: .serif, weight: .regular)
    static let insightSerif = Font.system(.headline, design: .serif, weight: .regular)

    // Numerals
    static func amountDisplay() -> Font { .system(size: 52, weight: .medium, design: .rounded) }
    static let amountHero = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    static let amountTitle = Font.system(.title3, design: .rounded, weight: .semibold)
    static let amountBody = Font.system(.callout, design: .rounded, weight: .medium)
    static let amountCaption = Font.system(.footnote, design: .rounded, weight: .medium)

    // UI
    static let headline = Font.headline
    static let body = Font.body
    static let callout = Font.callout
    static let caption = Font.caption
    static let micro = Font.system(.caption2, weight: .semibold)
}

// The small grey uppercase label above a section. Used sparingly — it's seasoning.
struct MicroLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Typography.micro)
            .tracking(0.8)
            .foregroundStyle(Palette.inkTertiary)
            .accessibilityLabel(text)
    }
}

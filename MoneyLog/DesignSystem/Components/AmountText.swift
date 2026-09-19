import SwiftUI

// Draws a money amount. Every ₹ figure on screen comes through here.
//
// Two things it gets right that are easy to get wrong by hand: the digits are
// fixed-width so columns line up, and when the value changes the digits roll into
// their new position instead of blinking.
struct AmountText: View {
    enum Size {
        case display, hero, title, body, caption

        var font: Font {
            switch self {
            case .display: Typography.amountDisplay()
            case .hero: Typography.amountHero
            case .title: Typography.amountTitle
            case .body: Typography.amountBody
            case .caption: Typography.amountCaption
            }
        }
    }

    let money: Money
    var size: Size = .body
    var color: Color?
    var showsPlusSign = false
    var fraction: MoneyFormatter.FractionPolicy = .automatic

    var body: some View {
        Text(MoneyFormatter.string(money, fraction: fraction, showsPlusSign: showsPlusSign))
            .font(size.font)
            .monospacedDigit()
            .foregroundStyle(color ?? Palette.ink)
            .contentTransition(.numericText(value: Double(money.minorUnits)))
            .accessibilityLabel(MoneyFormatter.string(money, fraction: .always))
    }
}

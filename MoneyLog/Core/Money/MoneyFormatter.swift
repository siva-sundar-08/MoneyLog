import Foundation

// Turns a Money value into text for the screen.
//
// Everything goes through here so amounts look the same everywhere, and so the
// grouping follows the user's region: ₹1,50,000 in India, $150,000 in the US.
// If you ever need to change how money reads, this is the only file to touch.
enum MoneyFormatter {
    enum FractionPolicy: Sendable {
        // ₹250 for a round number, ₹250.75 when there are paise. The usual choice.
        case automatic
        // Always ₹250.00 — for places where a column of numbers should line up.
        case always
        // Rounded to whole rupees. Used where paise would just be noise.
        case never
    }

    static func string(
        _ money: Money,
        fraction: FractionPolicy = .automatic,
        showsPlusSign: Bool = false,
        locale: Locale = .current
    ) -> String {
        let digits: Int
        switch fraction {
        case .automatic: digits = money.isWholeMajorUnit ? 0 : money.currency.minorUnitDigits
        case .always: digits = money.currency.minorUnitDigits
        case .never: digits = 0
        }
        let style = Decimal.FormatStyle.Currency(code: money.currency.rawValue, locale: locale)
            .precision(.fractionLength(digits))
        let formatted = money.decimalValue.formatted(style)
        return (showsPlusSign && money.isPositive) ? "+" + formatted : formatted
    }

    // Short form for tight spaces: ₹12K, or ₹1.2L in India.
    static func compactString(_ money: Money, locale: Locale = .current) -> String {
        let symbol = currencySymbol(for: money.currency, locale: locale)
        let number = money.decimalValue.formatted(
            .number.notation(.compactName).precision(.significantDigits(1...3)).locale(locale)
        )
        return symbol + number
    }

    static func currencySymbol(for currency: CurrencyCode, locale: Locale = .current) -> String {
        var components = Locale.Components(locale: locale)
        components.currency = Locale.Currency(currency.rawValue)
        return Locale(components: components).currencySymbol ?? currency.rawValue
    }
}

extension Money {
    func formatted(_ fraction: MoneyFormatter.FractionPolicy = .automatic, showsPlusSign: Bool = false) -> String {
        MoneyFormatter.string(self, fraction: fraction, showsPlusSign: showsPlusSign)
    }
}

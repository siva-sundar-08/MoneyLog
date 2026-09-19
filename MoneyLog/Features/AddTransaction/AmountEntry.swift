import Foundation

// Holds what the user has tapped on the keypad, before it becomes a Money value.
//
// The rule: digits fill the rupees first, and only go into paise after the user
// taps the decimal point. So "250" means ₹250, not ₹2.50.
//
// Some apps do the opposite, filling from the right so 250 becomes ₹2.50. It's
// faster once you're used to it and baffling until you are.
struct AmountEntry: Equatable {
    private(set) var wholeDigits = ""
    private(set) var fractionDigits: String?

    let currency: CurrencyCode

    init(currency: CurrencyCode) {
        self.currency = currency
    }

    // Start from an amount that already exists — used when editing a transaction.
    init(currency: CurrencyCode, minorUnits: Int64) {
        self.currency = currency
        guard minorUnits > 0 else { return }
        let scale = currency.minorUnitScale
        wholeDigits = String(minorUnits / scale)
        let remainder = minorUnits % scale
        if remainder > 0, currency.minorUnitDigits > 0 {
            fractionDigits = String(format: "%0\(currency.minorUnitDigits)d", Int(remainder))
        }
    }

    private var maximumWholeDigits: Int { 11 }

    var isEmpty: Bool { wholeDigits.isEmpty && fractionDigits == nil }

    var money: Money {
        let whole = Int64(wholeDigits) ?? 0
        let scale = currency.minorUnitScale
        var minor = whole * scale
        if let fractionDigits, currency.minorUnitDigits > 0 {
            let padded = fractionDigits.padding(toLength: currency.minorUnitDigits, withPad: "0", startingAt: 0)
            minor += Int64(padded) ?? 0
        }
        return Money(minorUnits: minor, currency: currency)
    }

    // The text shown on screen while typing. The rupees get grouped (1,50,000) and
    // the paise are shown exactly as typed, so "250." keeps its dot while you're
    // mid-entry rather than helpfully deleting it.
    func displayString(locale: Locale = .current) -> String {
        let whole = Int64(wholeDigits) ?? 0
        var text = whole.formatted(.number.grouping(.automatic).locale(locale))
        if let fractionDigits {
            let separator = locale.decimalSeparator ?? "."
            text += separator + fractionDigits
        }
        return text
    }

    mutating func append(digit: Int) {
        if fractionDigits != nil {
            guard fractionDigits!.count < currency.minorUnitDigits else { return }
            fractionDigits! += String(digit)
        } else {
            guard wholeDigits.count < maximumWholeDigits else { return }
            if wholeDigits.isEmpty && digit == 0 { wholeDigits = "0"; return }
            if wholeDigits == "0" { wholeDigits = String(digit); return }
            wholeDigits += String(digit)
        }
    }

    mutating func appendDecimalSeparator() {
        guard currency.minorUnitDigits > 0, fractionDigits == nil else { return }
        if wholeDigits.isEmpty { wholeDigits = "0" }
        fractionDigits = ""
    }

    mutating func deleteBackward() {
        if var fraction = fractionDigits {
            if fraction.isEmpty {
                fractionDigits = nil
            } else {
                fraction.removeLast()
                fractionDigits = fraction
            }
        } else if !wholeDigits.isEmpty {
            wholeDigits.removeLast()
        }
    }

    mutating func clear() {
        wholeDigits = ""
        fractionDigits = nil
    }
}

import Foundation

// An amount of money.
//
// The important bit: we store whole paise in an Int64, never rupees in a Double.
// Doubles can't hold 0.1 exactly, so adding them up drifts — a paisa here and
// there, and eventually the totals stop matching. Whole numbers can't drift.
//
// So ₹250.75 is stored as 25075. `minorUnits` is that number, and `currency`
// says what those units are.
//
// Adding two different currencies together is a bug rather than something to
// guess at, so it stops the app in debug instead of quietly producing nonsense.
struct Money: Hashable, Codable, Sendable {
    var minorUnits: Int64
    var currency: CurrencyCode

    init(minorUnits: Int64, currency: CurrencyCode = .default) {
        self.minorUnits = minorUnits
        self.currency = currency
    }

    // Build money from a normal decimal like 250.75.
    // Rounds to the nearest paisa, and returns nil if the number is so large it
    // wouldn't fit — better than silently wrapping around to a wrong value.
    init?(decimal: Decimal, currency: CurrencyCode = .default) {
        guard decimal.isFinite else { return nil }
        var scaled = decimal * Decimal(currency.minorUnitScale)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        guard rounded <= Decimal(Int64.max), rounded >= Decimal(Int64.min + 1) else { return nil }
        self.init(minorUnits: NSDecimalNumber(decimal: rounded).int64Value, currency: currency)
    }

    static func zero(_ currency: CurrencyCode = .default) -> Money {
        Money(minorUnits: 0, currency: currency)
    }

    var decimalValue: Decimal {
        Decimal(minorUnits) / Decimal(currency.minorUnitScale)
    }

    var isZero: Bool { minorUnits == 0 }
    var isPositive: Bool { minorUnits > 0 }
    var isNegative: Bool { minorUnits < 0 }
    var magnitude: Money { Money(minorUnits: minorUnits == .min ? .max : abs(minorUnits), currency: currency) }
    var negated: Money { Money(minorUnits: -minorUnits, currency: currency) }

    // True when there's nothing after the decimal point, e.g. ₹250.00 exactly.
    var isWholeMajorUnit: Bool { minorUnits % currency.minorUnitScale == 0 }
}

extension Money: Comparable {
    static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "Cannot compare \(lhs.currency.rawValue) with \(rhs.currency.rawValue)")
        return lhs.minorUnits < rhs.minorUnits
    }
}

extension Money {
    static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Cannot add \(lhs.currency.rawValue) to \(rhs.currency.rawValue)")
        return Money(minorUnits: lhs.minorUnits + rhs.minorUnits, currency: lhs.currency)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Cannot subtract \(rhs.currency.rawValue) from \(lhs.currency.rawValue)")
        return Money(minorUnits: lhs.minorUnits - rhs.minorUnits, currency: lhs.currency)
    }

    static func += (lhs: inout Money, rhs: Money) { lhs = lhs + rhs }
    static func -= (lhs: inout Money, rhs: Money) { lhs = lhs - rhs }
}

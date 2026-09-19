import Foundation
import Testing
@testable import MoneyLog

// Tests for money arithmetic and formatting.
//
// This is the file to keep honest. Everything else in the app is built on the
// idea that amounts are exact, so if these pass, wrong totals have to come from
// somewhere else.
@Suite("Money")
struct MoneyTests {
    @Test func decimalRoundTripIsExact() throws {
        let money = try #require(Money(decimal: Decimal(string: "1234.56")!, currency: .inr))
        #expect(money.minorUnits == 123_456)
        #expect(money.decimalValue == Decimal(string: "1234.56")!)
    }

    @Test func decimalRoundsHalfUp() throws {
        let money = try #require(Money(decimal: Decimal(string: "0.105")!, currency: .inr))
        #expect(money.minorUnits == 11)
    }

    @Test func zeroDecimalCurrencies() throws {
        let yen = CurrencyCode(rawValue: "jpy")
        #expect(yen.rawValue == "JPY")
        #expect(yen.minorUnitScale == 1)
        let money = try #require(Money(decimal: 500, currency: yen))
        #expect(money.minorUnits == 500)
    }

    @Test func arithmeticAndComparison() {
        let a = Money.inr(100)
        let b = Money.inr(40)
        #expect((a - b) == .inr(60))
        #expect((a + b).minorUnits == 14_000)
        #expect(b < a)
        #expect((b - a).isNegative)
        #expect((b - a).magnitude == .inr(60))
    }

    @Test func formattingUsesIndianGroupingAndHidesWholeFraction() {
        let india = Locale(identifier: "en_IN")
        let formatted = MoneyFormatter.string(.inr(150_000), locale: india)
        #expect(formatted.contains("₹"))
        #expect(formatted.contains("1,50,000"))
        #expect(!formatted.contains(".00"))

        let fractional = MoneyFormatter.string(Money(minorUnits: 12_345, currency: .inr), locale: india)
        #expect(fractional.contains("123.45"))
    }

    @Test func plusSignOnlyForPositive() {
        let india = Locale(identifier: "en_IN")
        #expect(MoneyFormatter.string(.inr(5), showsPlusSign: true, locale: india).hasPrefix("+"))
        #expect(!MoneyFormatter.string(.zero(.inr), showsPlusSign: true, locale: india).hasPrefix("+"))
    }
}

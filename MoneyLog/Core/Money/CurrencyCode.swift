import Foundation

// A currency, identified by its three-letter code: "INR", "USD", "JPY".
//
// Every amount we save carries its own currency code. Right now the whole app
// uses one currency, so they're all the same — but storing it per record means
// we can add multi-currency later without rewriting the database.
//
// Why a struct instead of an enum? An enum would have to list every currency in
// the world up front. This way an unknown code still works.
struct CurrencyCode: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue.uppercased()
    }

    var id: String { rawValue }

    static let inr = CurrencyCode(rawValue: "INR")
    static let `default`: CurrencyCode = .inr

    // How many digits come after the decimal point.
    // Rupees and dollars have 2 (paise, cents). Yen has none. A few have 3.
    var minorUnitDigits: Int {
        switch rawValue {
        case "JPY", "KRW", "VND", "CLP", "ISK", "UGX", "PYG", "XAF", "XOF":
            return 0
        case "BHD", "KWD", "OMR", "JOD", "TND", "IQD", "LYD":
            return 3
        default:
            return 2
        }
    }

    // How many small units make one big unit: 100 paise = ₹1.
    var minorUnitScale: Int64 {
        var scale: Int64 = 1
        for _ in 0..<minorUnitDigits { scale *= 10 }
        return scale
    }

    // The name in the user's own language, e.g. "Indian Rupee".
    func localizedName(locale: Locale = .current) -> String {
        locale.localizedString(forCurrencyCode: rawValue) ?? rawValue
    }

    // The short list we offer in Settings. Add to it whenever you like.
    static let supported: [CurrencyCode] = [
        "INR", "USD", "EUR", "GBP", "AED", "SGD", "AUD", "CAD", "JPY"
    ].map(CurrencyCode.init(rawValue:))
}

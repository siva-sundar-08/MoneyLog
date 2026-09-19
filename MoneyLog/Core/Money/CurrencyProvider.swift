import Foundation

// Answers one question: which currency is this app using?
//
// It's a protocol rather than a plain value so tests can hand in a fixed
// currency instead of depending on whatever is saved on the device.
protocol CurrencyProviding: Sendable {
    var currentCurrency: CurrencyCode { get }
}

enum PreferenceKey {
    static let currencyCode = "settings.currencyCode"
    static let appearance = "settings.appearance"
    static let hasSeededDefaults = "system.hasSeededDefaults"
}

struct UserDefaultsCurrencyProvider: CurrencyProviding, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentCurrency: CurrencyCode {
        guard let raw = defaults.string(forKey: PreferenceKey.currencyCode), !raw.isEmpty else {
            return .default
        }
        return CurrencyCode(rawValue: raw)
    }
}

struct FixedCurrencyProvider: CurrencyProviding {
    let currentCurrency: CurrencyCode
}

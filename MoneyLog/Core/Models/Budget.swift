import Foundation
import SwiftData

@Model
final class Budget {
    #Unique<Budget>([\.id])

    var id: UUID = UUID()
    var name: String = ""
    var limitMinor: Int64 = 0
    var currencyCode: String = CurrencyCode.default.rawValue
    var periodRaw: String = BudgetPeriod.monthly.rawValue
    // When to start warning, as a fraction: 0.8 means "tell me at 80% of the limit".
    var alertThreshold: Double = 0.8
    var rollsOver: Bool = false
    var isActive: Bool = true
    var createdAt: Date = Date.now

    // No category means this budget covers everything you spend.
    var category: TransactionCategory?

    // This initialiser only takes plain values, never other models.
    // SwiftData wants an object inserted into the database before you link it to
    // anything else, so the repositories do: create it, insert it, then connect it.
    init(
        id: UUID = UUID(),
        name: String,
        limit: Money,
        period: BudgetPeriod = .monthly,
        alertThreshold: Double = 0.8,
        rollsOver: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.limitMinor = limit.minorUnits
        self.currencyCode = limit.currency.rawValue
        self.periodRaw = period.rawValue
        self.alertThreshold = alertThreshold
        self.rollsOver = rollsOver
        self.createdAt = createdAt
    }
}

extension Budget {
    var period: BudgetPeriod {
        get { BudgetPeriod(rawValue: periodRaw) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    var limit: Money {
        get { Money(minorUnits: limitMinor, currency: CurrencyCode(rawValue: currencyCode)) }
        set {
            limitMinor = newValue.minorUnits
            currencyCode = newValue.currency.rawValue
        }
    }

    var isOverall: Bool { category == nil }
}

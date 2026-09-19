import Foundation
import SwiftData

@Model
final class SavingsGoal {
    #Unique<SavingsGoal>([\.id])

    var id: UUID = UUID()
    var name: String = ""
    var symbolName: String = "star"
    var tintRaw: String = TintKey.teal.rawValue
    var targetMinor: Int64 = 0
    var currencyCode: String = CurrencyCode.default.rawValue
    var targetDate: Date?
    var completedAt: Date?
    var isArchived: Bool = false
    var createdAt: Date = Date.now

    var linkedAccount: Account?

    @Relationship(deleteRule: .cascade, inverse: \GoalContribution.goal)
    var contributions: [GoalContribution] = []

    // This initialiser only takes plain values, never other models.
    // SwiftData wants an object inserted into the database before you link it to
    // anything else, so the repositories do: create it, insert it, then connect it.
    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        tint: TintKey,
        target: Money,
        targetDate: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.tintRaw = tint.rawValue
        self.targetMinor = target.minorUnits
        self.currencyCode = target.currency.rawValue
        self.targetDate = targetDate
        self.createdAt = createdAt
    }
}

extension SavingsGoal {
    var currency: CurrencyCode { CurrencyCode(rawValue: currencyCode) }

    var target: Money {
        get { Money(minorUnits: targetMinor, currency: currency) }
        set {
            targetMinor = newValue.minorUnits
            currencyCode = newValue.currency.rawValue
        }
    }

    var tint: TintKey {
        get { TintKey(rawValue: tintRaw) ?? .teal }
        set { tintRaw = newValue.rawValue }
    }

    var saved: Money {
        Money(minorUnits: contributions.reduce(0) { $0 + $1.amountMinor }, currency: currency)
    }

    var progress: GoalProgress {
        GoalProgress(savedMinor: saved.minorUnits, targetMinor: targetMinor, targetDate: targetDate, createdAt: createdAt)
    }

    var isCompleted: Bool { completedAt != nil }
}

@Model
final class GoalContribution {
    #Unique<GoalContribution>([\.id])

    var id: UUID = UUID()
    // Positive when you put money in, negative when you take some back out.
    var amountMinor: Int64 = 0
    var date: Date = Date.now
    var note: String?

    var goal: SavingsGoal?

    init(id: UUID = UUID(), amountMinor: Int64, date: Date = .now, note: String? = nil) {
        self.id = id
        self.amountMinor = amountMinor
        self.date = date
        self.note = note
    }
}

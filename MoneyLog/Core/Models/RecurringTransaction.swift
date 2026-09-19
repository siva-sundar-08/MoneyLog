import Foundation
import SwiftData

// A rule for something that repeats: rent on the 1st, Netflix every month.
//
// This is not a transaction itself — it's the instruction for making them.
// RecurrenceEngine reads these rules and creates the real rows when they fall due.
@Model
final class RecurringTransaction {
    #Unique<RecurringTransaction>([\.id])

    var id: UUID = UUID()
    var amountMinor: Int64 = 0
    var currencyCode: String = CurrencyCode.default.rawValue
    var typeRaw: String = TransactionType.expense.rawValue
    var merchant: String?
    var note: String?
    var frequencyRaw: String = RecurringFrequency.monthly.rawValue
    var startDate: Date = Date.now
    var endDate: Date?
    // Which repeat we're up to. 0 is the very first one (the start date), 1 is the
    // next, and so on. Counting them means we never create the same one twice.
    var occurrenceIndex: Int = 0
    // When the next one is due. Empty once the rule has run out (past its end date).
    var nextDueDate: Date?
    var isPaused: Bool = false
    var remindDaysBefore: Int?
    var createdAt: Date = Date.now

    var account: Account?
    var destinationAccount: Account?
    var category: TransactionCategory?

    @Relationship(deleteRule: .nullify, inverse: \TransactionRecord.recurringRule)
    var generatedTransactions: [TransactionRecord] = []

    // This initialiser only takes plain values, never other models.
    // SwiftData wants an object inserted into the database before you link it to
    // anything else, so the repositories do: create it, insert it, then connect it.
    init(
        id: UUID = UUID(),
        amount: Money,
        type: TransactionType,
        frequency: RecurringFrequency,
        startDate: Date,
        endDate: Date? = nil,
        merchant: String? = nil,
        note: String? = nil,
        remindDaysBefore: Int? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amountMinor = amount.minorUnits
        self.currencyCode = amount.currency.rawValue
        self.typeRaw = type.rawValue
        self.frequencyRaw = frequency.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.nextDueDate = startDate
        self.merchant = merchant
        self.note = note
        self.remindDaysBefore = remindDaysBefore
        self.createdAt = createdAt
    }
}

extension RecurringTransaction {
    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var amount: Money {
        get { Money(minorUnits: amountMinor, currency: CurrencyCode(rawValue: currencyCode)) }
        set {
            amountMinor = newValue.minorUnits
            currencyCode = newValue.currency.rawValue
        }
    }

    var hasEnded: Bool { nextDueDate == nil }

    func schedule(calendar: Calendar) -> RecurrenceSchedule {
        RecurrenceSchedule(start: startDate, frequency: frequency, end: endDate, calendar: calendar)
    }
}

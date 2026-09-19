import Foundation
import SwiftData

// One movement of money: a purchase, a salary credit, a transfer between accounts.
// This is the row you see in the Activity list.
//
// It's called TransactionRecord and not simply Transaction because SwiftUI
// already has a type called Transaction, and every view file imports SwiftUI.
// Two types with one name is a fight you don't want to keep having.
@Model
final class TransactionRecord {
    #Unique<TransactionRecord>([\.id])
    #Index<TransactionRecord>([\.date], [\.typeRaw, \.date])

    var id: UUID = UUID()
    // Always a positive number. Whether it's money in or money out comes from
    // `type`, not from a minus sign — that keeps the maths in one place.
    var amountMinor: Int64 = 0
    var currencyCode: String = CurrencyCode.default.rawValue
    var typeRaw: String = TransactionType.expense.rawValue
    var date: Date = Date.now
    var merchant: String?
    var note: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var account: Account?
    // Only used for transfers: the account the money went to.
    var destinationAccount: Account?
    // Empty for transfers — moving your own money isn't spending.
    var category: TransactionCategory?
    // Set if this row was created automatically by a repeating rule.
    var recurringRule: RecurringTransaction?

    // This initialiser only takes plain values, never other models.
    // SwiftData wants an object inserted into the database before you link it to
    // anything else, so the repositories do: create it, insert it, then connect it.
    init(
        id: UUID = UUID(),
        amount: Money,
        type: TransactionType,
        date: Date,
        merchant: String? = nil,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amountMinor = amount.minorUnits
        self.currencyCode = amount.currency.rawValue
        self.typeRaw = type.rawValue
        self.date = date
        self.merchant = merchant
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension TransactionRecord {
    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var currency: CurrencyCode { CurrencyCode(rawValue: currencyCode) }

    var amount: Money {
        get { Money(minorUnits: amountMinor, currency: currency) }
        set {
            amountMinor = newValue.minorUnits
            currencyCode = newValue.currency.rawValue
        }
    }

    // What to show as the row's title: the shop name if we have it, otherwise the
    // category, otherwise just "Expense". Never blank.
    var displayTitle: String {
        if let merchant, !merchant.isEmpty { return merchant }
        if let category { return category.name }
        return type.localizedName
    }

    var ledgerLine: LedgerLine {
        LedgerLine(
            amountMinor: amountMinor,
            type: type,
            date: date,
            accountID: account?.id,
            destinationAccountID: destinationAccount?.id,
            categoryID: category?.id
        )
    }
}

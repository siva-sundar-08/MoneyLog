import Foundation

// What the user has typed so far, before it becomes a real transaction.
//
// The Add screen fills one of these in as you tap around. Only when you press
// Save does a repository check it and write it to the database. Keeping the
// half-finished version separate means a cancelled entry leaves nothing behind.
struct TransactionDraft: Equatable, Sendable {
    var amount: Money
    var type: TransactionType
    var date: Date
    var accountID: UUID?
    var destinationAccountID: UUID?
    var categoryID: UUID?
    var merchant: String
    var note: String

    init(
        amount: Money,
        type: TransactionType = .expense,
        date: Date = .now,
        accountID: UUID? = nil,
        destinationAccountID: UUID? = nil,
        categoryID: UUID? = nil,
        merchant: String = "",
        note: String = ""
    ) {
        self.amount = amount
        self.type = type
        self.date = date
        self.accountID = accountID
        self.destinationAccountID = destinationAccountID
        self.categoryID = categoryID
        self.merchant = merchant
        self.note = note
    }

    var trimmedMerchant: String? { merchant.trimmedNilIfEmpty }
    var trimmedNote: String? { note.trimmedNilIfEmpty }
}

// Checks the obvious things: is there an amount, an account, a category?
//
// The deeper checks — does that account still exist, does the category match the
// transaction type — happen in the repository, because only it can look them up.
enum TransactionValidator {
    // An absurd upper limit (₹10,000 crore). Not a real rule — it's there to catch
    // a stuck finger on the keypad before a nonsense number reaches the database.
    static let maximumMinorUnits: Int64 = 10_000_000_000_000
    static let maximumYearsFromNow = 10

    static func validate(_ draft: TransactionDraft, now: Date = .now, calendar: Calendar = .current) throws {
        guard draft.amount.minorUnits > 0 else { throw AppError.validation(.amountNotPositive) }
        guard draft.amount.minorUnits <= maximumMinorUnits else { throw AppError.validation(.amountTooLarge) }
        guard draft.accountID != nil else { throw AppError.validation(.missingAccount) }

        switch draft.type {
        case .transfer:
            guard let destination = draft.destinationAccountID else {
                throw AppError.validation(.missingDestinationAccount)
            }
            guard destination != draft.accountID else { throw AppError.validation(.transferToSameAccount) }
        case .expense, .income:
            guard draft.categoryID != nil else { throw AppError.validation(.missingCategory) }
        }

        guard
            let lower = calendar.date(byAdding: .year, value: -100, to: now),
            let upper = calendar.date(byAdding: .year, value: maximumYearsFromNow, to: now),
            (lower...upper).contains(draft.date)
        else {
            throw AppError.validation(.dateOutOfRange)
        }
    }
}

extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

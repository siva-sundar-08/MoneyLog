import Foundation

// Every problem the user might see, in one place.
//
// The rule in this app: nothing fails quietly. If a save doesn't work, something
// throws one of these, and the screen shows the message. A button that does
// nothing and explains nothing is the worst possible outcome.
enum AppError: LocalizedError, Equatable {
    enum Operation: String, Sendable {
        case fetch, save, delete
    }

    case storeUnavailable(underlying: String)
    case persistence(operation: Operation, underlying: String)
    case validation(ValidationIssue)
    case notFound(entity: String)
    case duplicate(entity: String, name: String)
    case accountHasTransactions(count: Int)
    case categoryInUse(count: Int)

    var errorDescription: String? {
        switch self {
        case .storeUnavailable:
            String(localized: "error.storeUnavailable", defaultValue: "MoneyLog couldn't open your data on this device.")
        case .persistence(let operation, _):
            switch operation {
            case .fetch: String(localized: "error.fetch", defaultValue: "Couldn't load your data.")
            case .save: String(localized: "error.save", defaultValue: "Couldn't save your changes.")
            case .delete: String(localized: "error.delete", defaultValue: "Couldn't delete that item.")
            }
        case .validation(let issue):
            issue.message
        case .notFound:
            String(localized: "error.notFound", defaultValue: "That item no longer exists.")
        case .duplicate(_, let name):
            String(localized: "error.duplicate", defaultValue: "“\(name)” already exists.")
        case .accountHasTransactions(let count):
            String(localized: "error.accountHasTransactions", defaultValue: "This account has \(count) transactions. Archive it, or move its transactions first.")
        case .categoryInUse(let count):
            String(localized: "error.categoryInUse", defaultValue: "This category is used by \(count) transactions. Archive it instead to keep your history intact.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storeUnavailable, .persistence:
            String(localized: "error.recovery.retry", defaultValue: "Please try again. Your existing data has not been changed.")
        default:
            nil
        }
    }
}

enum ValidationIssue: Equatable, Sendable {
    case amountNotPositive
    case amountTooLarge
    case missingAccount
    case missingCategory
    case categoryTypeMismatch
    case missingDestinationAccount
    case transferToSameAccount
    case currencyMismatch
    case dateOutOfRange
    case emptyName
    case invalidThreshold
    case endBeforeStart

    var message: String {
        switch self {
        case .amountNotPositive: String(localized: "validation.amountNotPositive", defaultValue: "Enter an amount greater than zero.")
        case .amountTooLarge: String(localized: "validation.amountTooLarge", defaultValue: "That amount is larger than MoneyLog supports.")
        case .missingAccount: String(localized: "validation.missingAccount", defaultValue: "Choose an account.")
        case .missingCategory: String(localized: "validation.missingCategory", defaultValue: "Choose a category.")
        case .categoryTypeMismatch: String(localized: "validation.categoryTypeMismatch", defaultValue: "That category doesn't match this transaction type.")
        case .missingDestinationAccount: String(localized: "validation.missingDestination", defaultValue: "Choose where the money is going.")
        case .transferToSameAccount: String(localized: "validation.sameAccount", defaultValue: "Pick two different accounts for a transfer.")
        case .currencyMismatch: String(localized: "validation.currencyMismatch", defaultValue: "This amount's currency doesn't match the account.")
        case .dateOutOfRange: String(localized: "validation.dateOutOfRange", defaultValue: "Choose a date within a reasonable range.")
        case .emptyName: String(localized: "validation.emptyName", defaultValue: "Add a name.")
        case .invalidThreshold: String(localized: "validation.invalidThreshold", defaultValue: "The alert level must be between 1% and 100%.")
        case .endBeforeStart: String(localized: "validation.endBeforeStart", defaultValue: "The end date must be after the start date.")
        }
    }
}

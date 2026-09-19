import Foundation
import SwiftData

// A place money sits: cash in your pocket, a bank account, a credit card, a wallet.
//
// Note there's no `balance` stored here. A stored balance goes stale the moment
// something changes, so we keep only the starting amount and add up the
// transactions whenever we need the current figure. See BalanceCalculator.
@Model
final class Account {
    #Unique<Account>([\.id])

    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = AccountType.bank.rawValue
    var openingBalanceMinor: Int64 = 0
    var currencyCode: String = CurrencyCode.default.rawValue
    var tintRaw: String = TintKey.teal.rawValue
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \TransactionRecord.account)
    var transactions: [TransactionRecord] = []

    @Relationship(deleteRule: .nullify, inverse: \TransactionRecord.destinationAccount)
    var incomingTransfers: [TransactionRecord] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.account)
    var recurringRules: [RecurringTransaction] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.destinationAccount)
    var incomingRecurringTransfers: [RecurringTransaction] = []

    @Relationship(deleteRule: .nullify, inverse: \SavingsGoal.linkedAccount)
    var linkedGoals: [SavingsGoal] = []

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        openingBalance: Money,
        tint: TintKey = .teal,
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.openingBalanceMinor = openingBalance.minorUnits
        self.currencyCode = openingBalance.currency.rawValue
        self.tintRaw = tint.rawValue
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

extension Account {
    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .bank }
        set { typeRaw = newValue.rawValue }
    }

    var currency: CurrencyCode { CurrencyCode(rawValue: currencyCode) }

    var openingBalance: Money {
        get { Money(minorUnits: openingBalanceMinor, currency: currency) }
        set {
            openingBalanceMinor = newValue.minorUnits
            currencyCode = newValue.currency.rawValue
        }
    }

    var tint: TintKey {
        get { TintKey(rawValue: tintRaw) ?? .teal }
        set { tintRaw = newValue.rawValue }
    }

    var hasActivity: Bool {
        !transactions.isEmpty || !incomingTransfers.isEmpty
    }
}

import Foundation
import SwiftData

struct AccountDraft: Equatable, Sendable {
    var name: String
    var type: AccountType
    var openingBalance: Money
    var tint: TintKey = .teal
}

// Reads and writes accounts, and works out what each one is worth right now.
@MainActor
protocol AccountRepository: AnyObject {
    func accounts(includeArchived: Bool) throws -> [Account]
    @discardableResult func create(_ draft: AccountDraft) throws -> Account
    func update(_ account: Account, with draft: AccountDraft) throws
    func setArchived(_ account: Account, _ archived: Bool) throws
    func delete(_ account: Account) throws
    func reorder(_ accounts: [Account]) throws
    func balances() throws -> [UUID: Money]
    func balance(of account: Account) throws -> Money
    // Everything you have, minus what you owe. Credit cards come out negative on
    // their own, so a plain sum gives the right answer.
    func netWorth() throws -> Money
}

@MainActor
final class SwiftDataAccountRepository: AccountRepository {
    private let context: ModelContext
    private let currency: any CurrencyProviding

    init(context: ModelContext, currency: any CurrencyProviding) {
        self.context = context
        self.currency = currency
    }

    func accounts(includeArchived: Bool = false) throws -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            predicate: includeArchived ? nil : #Predicate { $0.isArchived == false },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return try context.fetchOrThrow(descriptor)
    }

    @discardableResult
    func create(_ draft: AccountDraft) throws -> Account {
        let name = try validatedName(draft.name, excluding: nil)
        let nextOrder = (try accounts(includeArchived: true).map(\.sortOrder).max() ?? -1) + 1
        let account = Account(name: name, type: draft.type, openingBalance: draft.openingBalance, tint: draft.tint, sortOrder: nextOrder)
        context.insert(account)
        try context.saveOrRollback()
        return account
    }

    func update(_ account: Account, with draft: AccountDraft) throws {
        account.name = try validatedName(draft.name, excluding: account.id)
        account.type = draft.type
        account.openingBalance = draft.openingBalance
        account.tint = draft.tint
        try context.saveOrRollback()
    }

    func setArchived(_ account: Account, _ archived: Bool) throws {
        account.isArchived = archived
        try context.saveOrRollback()
    }

    // Deleting an account that has transactions would quietly change your past
    // totals, so we refuse and suggest archiving instead. Archived accounts stay
    // out of the way but keep the history honest.
    func delete(_ account: Account) throws {
        let count = account.transactions.count + account.incomingTransfers.count
        guard count == 0 else { throw AppError.accountHasTransactions(count: count) }
        context.delete(account)
        try context.saveOrRollback(operation: .delete)
    }

    func reorder(_ accounts: [Account]) throws {
        for (index, account) in accounts.enumerated() { account.sortOrder = index }
        try context.saveOrRollback()
    }

    func balances() throws -> [UUID: Money] {
        let all = try accounts(includeArchived: true)
        let opening = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.openingBalanceMinor) })
        let lines = try context.fetchOrThrow(FetchDescriptor<TransactionRecord>()).map(\.ledgerLine)
        let totals = BalanceCalculator.balances(openingBalances: opening, lines: lines)
        return Dictionary(uniqueKeysWithValues: all.map { account in
            (account.id, Money(minorUnits: totals[account.id] ?? account.openingBalanceMinor, currency: account.currency))
        })
    }

    func balance(of account: Account) throws -> Money {
        let lines = (account.transactions + account.incomingTransfers).map(\.ledgerLine)
        let delta = lines.reduce(Int64(0)) { $0 + BalanceCalculator.delta(of: $1, on: account.id) }
        return Money(minorUnits: account.openingBalanceMinor + delta, currency: account.currency)
    }

    func netWorth() throws -> Money {
        let active = Set(try accounts(includeArchived: false).map(\.id))
        let total = try balances()
            .filter { active.contains($0.key) }
            .values
            .reduce(Int64(0)) { $0 + $1.minorUnits }
        return Money(minorUnits: total, currency: currency.currentCurrency)
    }

    private func validatedName(_ raw: String, excluding id: UUID?) throws -> String {
        guard let name = raw.trimmedNilIfEmpty else { throw AppError.validation(.emptyName) }
        let clash = try accounts(includeArchived: true).contains {
            $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
        if clash { throw AppError.duplicate(entity: "Account", name: name) }
        return name
    }
}

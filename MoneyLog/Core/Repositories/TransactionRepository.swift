import Foundation
import SwiftData

struct TransactionQuery: Equatable, Sendable {
    var interval: DateInterval?
    var types: Set<TransactionType> = []
    var categoryIDs: Set<UUID> = []
    var accountIDs: Set<UUID> = []
    var searchText: String = ""
    var limit: Int?

    static let all = TransactionQuery()

    static func recent(_ limit: Int) -> TransactionQuery {
        TransactionQuery(limit: limit)
    }

    // Some filters the database can do itself; searching text and matching lists of
    // categories is easier in Swift after the fetch. This says which case we're in.
    var needsInMemoryFiltering: Bool {
        types.count > 1 || !categoryIDs.isEmpty || !accountIDs.isEmpty || searchText.trimmedNilIfEmpty != nil
    }
}

// The only code allowed to read or write transactions in the database.
//
// This pattern is called a repository. The idea: screens ask for what they want
// ("recent transactions", "save this") and never touch SwiftData directly. Two
// benefits — the rules about valid data live in one place, and tests can swap in
// a fake repository without a database at all.
//
// The protocol is the list of what you can ask for; the class below it is how it's
// actually done.
@MainActor
protocol TransactionRepository: AnyObject {
    func transactions(matching query: TransactionQuery) throws -> [TransactionRecord]
    func ledgerLines(in interval: DateInterval?) throws -> [LedgerLine]
    @discardableResult func create(_ draft: TransactionDraft) throws -> TransactionRecord
    func update(_ transaction: TransactionRecord, with draft: TransactionDraft) throws
    func delete(_ transaction: TransactionRecord) throws
    func possibleDuplicate(of draft: TransactionDraft, within window: TimeInterval) throws -> TransactionRecord?
    func recentMerchants(limit: Int) throws -> [String]
}

@MainActor
final class SwiftDataTransactionRepository: TransactionRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    // MARK: Reading

    func transactions(matching query: TransactionQuery) throws -> [TransactionRecord] {
        var descriptor = FetchDescriptor<TransactionRecord>(
            predicate: Self.storePredicate(for: query),
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        if !query.needsInMemoryFiltering, let limit = query.limit {
            descriptor.fetchLimit = limit
        }

        var results = try context.fetchOrThrow(descriptor)
        guard query.needsInMemoryFiltering else { return results }

        results = results.filter { Self.matches($0, query: query) }
        if let limit = query.limit { results = Array(results.prefix(limit)) }
        return results
    }

    func ledgerLines(in interval: DateInterval?) throws -> [LedgerLine] {
        try transactions(matching: TransactionQuery(interval: interval)).map(\.ledgerLine)
    }

    func recentMerchants(limit: Int) throws -> [String] {
        var descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.merchant != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit * 10
        var seen = Set<String>()
        var result: [String] = []
        for record in try context.fetchOrThrow(descriptor) {
            guard let name = record.merchant?.trimmedNilIfEmpty else { continue }
            if seen.insert(name.lowercased()).inserted {
                result.append(name)
                if result.count == limit { break }
            }
        }
        return result
    }

    // MARK: Writing

    @discardableResult
    func create(_ draft: TransactionDraft) throws -> TransactionRecord {
        try TransactionValidator.validate(draft, calendar: calendar)
        let links = try resolveLinks(for: draft)

        let record = TransactionRecord(
            amount: draft.amount,
            type: draft.type,
            date: draft.date,
            merchant: draft.trimmedMerchant,
            note: draft.trimmedNote
        )
        context.insert(record)
        apply(links, to: record)
        links.category?.markUsed()

        try context.saveOrRollback()
        return record
    }

    func update(_ transaction: TransactionRecord, with draft: TransactionDraft) throws {
        try TransactionValidator.validate(draft, calendar: calendar)
        let links = try resolveLinks(for: draft)

        transaction.amount = draft.amount
        transaction.type = draft.type
        transaction.date = draft.date
        transaction.merchant = draft.trimmedMerchant
        transaction.note = draft.trimmedNote
        if transaction.category?.id != links.category?.id { links.category?.markUsed() }
        apply(links, to: transaction)
        transaction.updatedAt = .now

        try context.saveOrRollback()
    }

    func delete(_ transaction: TransactionRecord) throws {
        context.delete(transaction)
        try context.saveOrRollback(operation: .delete)
    }

    func possibleDuplicate(of draft: TransactionDraft, within window: TimeInterval = 120) throws -> TransactionRecord? {
        let lower = draft.date.addingTimeInterval(-window)
        let upper = draft.date.addingTimeInterval(window)
        let amount = draft.amount.minorUnits
        let typeRaw = draft.type.rawValue
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate {
                $0.date >= lower && $0.date <= upper && $0.amountMinor == amount && $0.typeRaw == typeRaw
            }
        )
        let merchant = draft.trimmedMerchant?.lowercased()
        return try context.fetchOrThrow(descriptor).first {
            $0.merchant?.lowercased() == merchant && $0.category?.id == draft.categoryID
        }
    }

    // MARK: Helpers

    private struct Links {
        let account: Account
        let destination: Account?
        let category: TransactionCategory?
    }

    private func resolveLinks(for draft: TransactionDraft) throws -> Links {
        guard let accountID = draft.accountID, let account = try context.account(id: accountID) else {
            throw AppError.validation(.missingAccount)
        }
        // Single-currency invariant for v1: amount must match the account.
        guard account.currency == draft.amount.currency else {
            throw AppError.validation(.currencyMismatch)
        }

        switch draft.type {
        case .transfer:
            guard let destinationID = draft.destinationAccountID,
                  let destination = try context.account(id: destinationID) else {
                throw AppError.validation(.missingDestinationAccount)
            }
            guard destination.currency == draft.amount.currency else {
                throw AppError.validation(.currencyMismatch)
            }
            return Links(account: account, destination: destination, category: nil)

        case .expense, .income:
            guard let categoryID = draft.categoryID, let category = try context.category(id: categoryID) else {
                throw AppError.validation(.missingCategory)
            }
            guard category.type == draft.type.requiredCategoryType else {
                throw AppError.validation(.categoryTypeMismatch)
            }
            return Links(account: account, destination: nil, category: category)
        }
    }

    private func apply(_ links: Links, to record: TransactionRecord) {
        record.account = links.account
        record.destinationAccount = links.destination
        record.category = links.category
    }

    private static func storePredicate(for query: TransactionQuery) -> Predicate<TransactionRecord>? {
        let singleType = query.types.count == 1 ? query.types.first?.rawValue : nil

        switch (query.interval, singleType) {
        case let (interval?, typeRaw?):
            let start = interval.start
            let end = interval.end
            return #Predicate { $0.typeRaw == typeRaw && $0.date >= start && $0.date < end }
        case let (interval?, nil):
            let start = interval.start
            let end = interval.end
            return #Predicate { $0.date >= start && $0.date < end }
        case let (nil, typeRaw?):
            return #Predicate { $0.typeRaw == typeRaw }
        case (nil, nil):
            return nil
        }
    }

    private static func matches(_ record: TransactionRecord, query: TransactionQuery) -> Bool {
        if !query.types.isEmpty, !query.types.contains(record.type) { return false }

        if !query.categoryIDs.isEmpty {
            guard let id = record.category?.id, query.categoryIDs.contains(id) else { return false }
        }

        if !query.accountIDs.isEmpty {
            let touched = [record.account?.id, record.destinationAccount?.id].compactMap { $0 }
            guard touched.contains(where: query.accountIDs.contains) else { return false }
        }

        if let search = query.searchText.trimmedNilIfEmpty {
            let haystack = [record.merchant, record.note, record.category?.name, record.account?.name]
                .compactMap { $0 }
            let amountText = record.amount.formatted(.always)
            guard haystack.contains(where: { $0.localizedStandardContains(search) })
                    || amountText.localizedStandardContains(search)
            else { return false }
        }
        return true
    }
}

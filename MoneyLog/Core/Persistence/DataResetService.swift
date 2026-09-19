import Foundation
import SwiftData
import OSLog

// Wipes everything and puts the starter categories back. Used by "Erase all data".
//
// It deletes row by row instead of using SwiftData's bulk delete. The bulk version
// looks tidier but fails on models that point at each other, which all of ours do.
// Children go first (contributions before goals) so nothing is left pointing at a
// record that no longer exists.
@MainActor
struct DataResetService {
    let context: ModelContext
    let currency: CurrencyCode

    private static let logger = Logger(subsystem: "com.wedzat.moneylog", category: "DataReset")

    func eraseAll(reseed: Bool = true) throws {
        do {
            try deleteAll(TransactionRecord.self)
            try deleteAll(GoalContribution.self)
            try deleteAll(RecurringTransaction.self)
            try deleteAll(Budget.self)
            try deleteAll(SavingsGoal.self)
            try deleteAll(TransactionCategory.self)
            try deleteAll(Account.self)
            try context.save()
        } catch {
            context.rollback()
            Self.logger.error("Erase failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.persistence(operation: .delete, underlying: error.localizedDescription)
        }

        if reseed {
            try SeedDataService(context: context, currency: currency).seedIfNeeded()
        }
    }

    func countOfTransactions() throws -> Int {
        try context.countOrThrow(FetchDescriptor<TransactionRecord>())
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        for object in try context.fetch(FetchDescriptor<T>()) {
            context.delete(object)
        }
    }
}

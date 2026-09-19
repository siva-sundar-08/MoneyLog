import Foundation
import SwiftData

// Small helpers over SwiftData's ModelContext (the thing that reads and writes
// the database).
//
// Two jobs: turn SwiftData's errors into our own AppError so screens have
// something sensible to show, and roll back a failed save so the app never
// displays changes that didn't actually stick.
extension ModelContext {
    func fetchOrThrow<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            throw AppError.persistence(operation: .fetch, underlying: error.localizedDescription)
        }
    }

    func countOrThrow<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> Int {
        do {
            return try fetchCount(descriptor)
        } catch {
            throw AppError.persistence(operation: .fetch, underlying: error.localizedDescription)
        }
    }

    // Save, and undo the pending changes if it fails.
    func saveOrRollback(operation: AppError.Operation = .save) throws {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            rollback()
            throw AppError.persistence(operation: operation, underlying: error.localizedDescription)
        }
    }

    func account(id: UUID) throws -> Account? {
        var descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try fetchOrThrow(descriptor).first
    }

    func category(id: UUID) throws -> TransactionCategory? {
        var descriptor = FetchDescriptor<TransactionCategory>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try fetchOrThrow(descriptor).first
    }
}

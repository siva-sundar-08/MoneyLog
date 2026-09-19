import Foundation
import SwiftData

struct CategoryDraft: Equatable, Sendable {
    var name: String
    var type: CategoryType
    var symbolName: String
    var tint: TintKey
    var parentID: UUID?
}

// Reads and writes categories.
//
// Note the difference between archive and delete. Archiving hides a category but
// leaves old transactions intact; deleting is only allowed when nothing uses it.
// Losing the label on last year's spending is not a trade anyone wants to make.
@MainActor
protocol CategoryRepository: AnyObject {
    func categories(of type: CategoryType?, includeArchived: Bool) throws -> [TransactionCategory]
    func recentlyUsed(of type: CategoryType, limit: Int) throws -> [TransactionCategory]
    @discardableResult func create(_ draft: CategoryDraft) throws -> TransactionCategory
    func update(_ category: TransactionCategory, with draft: CategoryDraft) throws
    func setArchived(_ category: TransactionCategory, _ archived: Bool) throws
    func delete(_ category: TransactionCategory) throws
    func reorder(_ categories: [TransactionCategory]) throws
}

@MainActor
final class SwiftDataCategoryRepository: CategoryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func categories(of type: CategoryType? = nil, includeArchived: Bool = false) throws -> [TransactionCategory] {
        let descriptor = FetchDescriptor<TransactionCategory>(
            predicate: Self.predicate(type: type, includeArchived: includeArchived),
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return try context.fetchOrThrow(descriptor)
    }

    func recentlyUsed(of type: CategoryType, limit: Int) throws -> [TransactionCategory] {
        let typeRaw = type.rawValue
        var descriptor = FetchDescriptor<TransactionCategory>(
            predicate: #Predicate { $0.typeRaw == typeRaw && $0.isArchived == false && $0.lastUsedAt != nil },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetchOrThrow(descriptor)
    }

    @discardableResult
    func create(_ draft: CategoryDraft) throws -> TransactionCategory {
        let name = try validatedName(draft.name, type: draft.type, excluding: nil)
        let nextOrder = (try categories(of: draft.type, includeArchived: true).map(\.sortOrder).max() ?? -1) + 1
        let category = TransactionCategory(name: name, type: draft.type, symbolName: draft.symbolName, tint: draft.tint, sortOrder: nextOrder)
        context.insert(category)
        category.parent = try resolveParent(draft.parentID, for: category)
        try context.saveOrRollback()
        return category
    }

    func update(_ category: TransactionCategory, with draft: CategoryDraft) throws {
        category.name = try validatedName(draft.name, type: draft.type, excluding: category.id)
        // Changing type would invalidate existing transactions, so it's only allowed when unused.
        if draft.type != category.type {
            guard category.transactions.isEmpty else { throw AppError.categoryInUse(count: category.transactions.count) }
            category.type = draft.type
        }
        category.symbolName = draft.symbolName
        category.tint = draft.tint
        category.parent = try resolveParent(draft.parentID, for: category)
        try context.saveOrRollback()
    }

    func setArchived(_ category: TransactionCategory, _ archived: Bool) throws {
        category.isArchived = archived
        try context.saveOrRollback()
    }

    func delete(_ category: TransactionCategory) throws {
        let count = category.transactions.count
        guard count == 0 else { throw AppError.categoryInUse(count: count) }
        context.delete(category)
        try context.saveOrRollback(operation: .delete)
    }

    func reorder(_ categories: [TransactionCategory]) throws {
        for (index, category) in categories.enumerated() { category.sortOrder = index }
        try context.saveOrRollback()
    }

    private func resolveParent(_ id: UUID?, for category: TransactionCategory) throws -> TransactionCategory? {
        guard let id else { return nil }
        guard id != category.id, let parent = try context.category(id: id) else {
            throw AppError.notFound(entity: "Category")
        }
        // Prevent cycles: the new parent can't be inside this category's subtree.
        guard !category.subtreeIDs.contains(parent.id), parent.type == category.type else {
            throw AppError.validation(.categoryTypeMismatch)
        }
        return parent
    }

    private func validatedName(_ raw: String, type: CategoryType, excluding id: UUID?) throws -> String {
        guard let name = raw.trimmedNilIfEmpty else { throw AppError.validation(.emptyName) }
        let clash = try categories(of: type, includeArchived: true).contains {
            $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
        if clash { throw AppError.duplicate(entity: "Category", name: name) }
        return name
    }

    private static func predicate(type: CategoryType?, includeArchived: Bool) -> Predicate<TransactionCategory>? {
        switch (type?.rawValue, includeArchived) {
        case let (typeRaw?, false):
            return #Predicate { $0.typeRaw == typeRaw && $0.isArchived == false }
        case let (typeRaw?, true):
            return #Predicate { $0.typeRaw == typeRaw }
        case (nil, false):
            return #Predicate { $0.isArchived == false }
        case (nil, true):
            return nil
        }
    }
}

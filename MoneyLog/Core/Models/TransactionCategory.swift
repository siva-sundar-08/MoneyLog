import Foundation
import SwiftData

@Model
final class TransactionCategory {
    #Unique<TransactionCategory>([\.id])

    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = CategoryType.expense.rawValue
    var symbolName: String = "square.grid.2x2"
    var tintRaw: String = TintKey.slate.rawValue
    var sortOrder: Int = 0
    var isArchived: Bool = false
    // For the categories we ship with ("food", "rent"). Lets us find them again
    // later even if the user renames them or the app changes language.
    var systemKey: String?
    var lastUsedAt: Date?
    var usageCount: Int = 0
    var createdAt: Date = Date.now

    var parent: TransactionCategory?

    @Relationship(deleteRule: .nullify, inverse: \TransactionCategory.parent)
    var children: [TransactionCategory] = []

    @Relationship(deleteRule: .nullify, inverse: \TransactionRecord.category)
    var transactions: [TransactionRecord] = []

    // Delete a category and its budget goes too — a budget for nothing is nothing.
    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.category)
    var recurringRules: [RecurringTransaction] = []

    // This initialiser only takes plain values, never other models.
    // SwiftData wants an object inserted into the database before you link it to
    // anything else, so the repositories do: create it, insert it, then connect it.
    init(
        id: UUID = UUID(),
        name: String,
        type: CategoryType,
        symbolName: String,
        tint: TintKey,
        sortOrder: Int = 0,
        systemKey: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.symbolName = symbolName
        self.tintRaw = tint.rawValue
        self.sortOrder = sortOrder
        self.systemKey = systemKey
        self.createdAt = createdAt
    }
}

extension TransactionCategory {
    var type: CategoryType {
        get { CategoryType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var tint: TintKey {
        get { TintKey(rawValue: tintRaw) ?? .slate }
        set { tintRaw = newValue.rawValue }
    }

    // This category and everything nested under it. A budget on "Food" should
    // count what you spent on "Coffee" if Coffee sits inside Food.
    var subtreeIDs: Set<UUID> {
        var ids: Set<UUID> = [id]
        for child in children { ids.formUnion(child.subtreeIDs) }
        return ids
    }

    func markUsed(at date: Date = .now) {
        lastUsedAt = date
        usageCount += 1
    }
}

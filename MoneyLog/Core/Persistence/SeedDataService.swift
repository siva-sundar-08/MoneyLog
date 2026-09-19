import Foundation
import SwiftData

// Gives a brand-new install something to work with: the starter categories and a
// Cash account.
//
// It checks before inserting, so running it twice does nothing the second time.
// That matters because it runs on every launch — simpler than remembering whether
// we've done it before.
@MainActor
struct SeedDataService {
    let context: ModelContext
    let currency: CurrencyCode

    struct CategorySeed {
        let key: String
        let name: String
        let symbol: String
        let tint: TintKey
        let type: CategoryType
    }

    static let expenseSeeds: [CategorySeed] = [
        .init(key: "food", name: String(localized: "category.food", defaultValue: "Food & Dining"), symbol: "fork.knife", tint: .terracotta, type: .expense),
        .init(key: "groceries", name: String(localized: "category.groceries", defaultValue: "Groceries"), symbol: "cart", tint: .moss, type: .expense),
        .init(key: "transport", name: String(localized: "category.transport", defaultValue: "Transport"), symbol: "car", tint: .slate, type: .expense),
        .init(key: "shopping", name: String(localized: "category.shopping", defaultValue: "Shopping"), symbol: "bag", tint: .plum, type: .expense),
        .init(key: "bills", name: String(localized: "category.bills", defaultValue: "Bills & Utilities"), symbol: "bolt", tint: .ochre, type: .expense),
        .init(key: "rent", name: String(localized: "category.rent", defaultValue: "Rent & Home"), symbol: "house", tint: .sand, type: .expense),
        .init(key: "entertainment", name: String(localized: "category.entertainment", defaultValue: "Entertainment"), symbol: "popcorn", tint: .indigo, type: .expense),
        .init(key: "health", name: String(localized: "category.health", defaultValue: "Health"), symbol: "cross.case", tint: .rose, type: .expense),
        .init(key: "travel", name: String(localized: "category.travel", defaultValue: "Travel"), symbol: "airplane", tint: .teal, type: .expense),
        .init(key: "education", name: String(localized: "category.education", defaultValue: "Education"), symbol: "book.closed", tint: .indigo, type: .expense),
        .init(key: "personalCare", name: String(localized: "category.personalCare", defaultValue: "Personal Care"), symbol: "sparkles", tint: .rose, type: .expense),
        .init(key: "gifts", name: String(localized: "category.gifts", defaultValue: "Gifts & Giving"), symbol: "gift", tint: .terracotta, type: .expense),
        .init(key: "otherExpense", name: String(localized: "category.otherExpense", defaultValue: "Other"), symbol: "square.grid.2x2", tint: .slate, type: .expense),
    ]

    static let incomeSeeds: [CategorySeed] = [
        .init(key: "salary", name: String(localized: "category.salary", defaultValue: "Salary"), symbol: "briefcase", tint: .sage, type: .income),
        .init(key: "business", name: String(localized: "category.business", defaultValue: "Business"), symbol: "building.2", tint: .teal, type: .income),
        .init(key: "freelance", name: String(localized: "category.freelance", defaultValue: "Freelance"), symbol: "laptopcomputer", tint: .moss, type: .income),
        .init(key: "investments", name: String(localized: "category.investments", defaultValue: "Investments"), symbol: "chart.line.uptrend.xyaxis", tint: .indigo, type: .income),
        .init(key: "refunds", name: String(localized: "category.refunds", defaultValue: "Refunds"), symbol: "arrow.uturn.backward", tint: .slate, type: .income),
        .init(key: "otherIncome", name: String(localized: "category.otherIncome", defaultValue: "Other Income"), symbol: "plus.circle", tint: .sand, type: .income),
    ]

    // Returns true only if it actually added something.
    @discardableResult
    func seedIfNeeded() throws -> Bool {
        var inserted = false

        if try context.fetchCount(FetchDescriptor<TransactionCategory>()) == 0 {
            for (index, seed) in (Self.expenseSeeds + Self.incomeSeeds).enumerated() {
                context.insert(TransactionCategory(
                    name: seed.name,
                    type: seed.type,
                    symbolName: seed.symbol,
                    tint: seed.tint,
                    sortOrder: index,
                    systemKey: seed.key
                ))
            }
            inserted = true
        }

        if try context.fetchCount(FetchDescriptor<Account>()) == 0 {
            context.insert(Account(
                name: String(localized: "account.defaultCash", defaultValue: "Cash"),
                type: .cash,
                openingBalance: .zero(currency),
                tint: .sage
            ))
            inserted = true
        }

        if inserted {
            do {
                try context.save()
            } catch {
                context.rollback()
                throw AppError.persistence(operation: .save, underlying: error.localizedDescription)
            }
        }
        return inserted
    }
}

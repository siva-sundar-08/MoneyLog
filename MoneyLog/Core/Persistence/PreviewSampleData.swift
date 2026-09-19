#if DEBUG
import Foundation
import SwiftData

// Fake data for Xcode previews.
//
// Previews need something to draw, and an empty app shows empty screens. The
// numbers here are fixed rather than random so a preview looks the same every
// time you open it. It never ships — the #if DEBUG below sees to that.
@MainActor
enum PreviewSampleData {
    static func makeContainer(now: Date = .now, calendar: Calendar = .current) -> ModelContainer {
        do {
            let container = try PersistenceController.makeContainer(location: .inMemory)
            try populate(container.mainContext, now: now, calendar: calendar)
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }

    static func populate(_ context: ModelContext, now: Date, calendar: Calendar) throws {
        let inr = CurrencyCode.inr
        try SeedDataService(context: context, currency: inr).seedIfNeeded()

        let bank = Account(name: "HDFC Savings", type: .bank, openingBalance: Money(minorUnits: 8_500_000, currency: inr), tint: .teal, sortOrder: 1)
        let card = Account(name: "Amex Platinum", type: .creditCard, openingBalance: .zero(inr), tint: .plum, sortOrder: 2)
        context.insert(bank)
        context.insert(card)

        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        func category(_ key: String) -> TransactionCategory? { categories.first { $0.systemKey == key } }

        let expenses: [(String, String, Int64, Account)] = [
            ("food", "Swiggy", 45_000, card), ("groceries", "Nilgiris", 182_000, bank),
            ("transport", "Uber", 32_000, card), ("food", "Third Wave Coffee", 28_000, card),
            ("shopping", "Amazon", 249_900, card), ("bills", "TNEB", 186_000, bank),
            ("entertainment", "PVR", 70_000, card), ("health", "Apollo Pharmacy", 54_000, bank),
        ]
        for day in 0..<45 {
            guard let date = calendar.date(byAdding: .day, value: -day, to: now) else { continue }
            let pick = expenses[day % expenses.count]
            let amount = pick.2 + Int64((day * 1_733) % 20_000)
            let record = TransactionRecord(
                amount: Money(minorUnits: amount, currency: inr),
                type: .expense,
                date: date,
                merchant: pick.1
            )
            context.insert(record)
            record.account = pick.3
            record.category = category(pick.0)
        }

        for monthsAgo in 0..<2 {
            guard let start = calendar.dateInterval(of: .month, for: now)?.start,
                  let date = calendar.date(byAdding: .month, value: -monthsAgo, to: start) else { continue }
            let salary = TransactionRecord(
                amount: Money(minorUnits: 18_000_000, currency: inr),
                type: .income,
                date: date,
                merchant: "WedZat Technologies"
            )
            context.insert(salary)
            salary.account = bank
            salary.category = category("salary")
        }

        context.insert(Budget(name: "Monthly", limit: Money(minorUnits: 6_000_000, currency: inr)))
        if let food = category("food") {
            let foodBudget = Budget(name: food.name, limit: Money(minorUnits: 800_000, currency: inr))
            context.insert(foodBudget)
            foodBudget.category = food
        }

        let goal = SavingsGoal(
            name: "New MacBook",
            symbolName: "laptopcomputer",
            tint: .indigo,
            target: Money(minorUnits: 20_000_000, currency: inr),
            targetDate: calendar.date(byAdding: .month, value: 5, to: now)
        )
        context.insert(goal)
        let contribution = GoalContribution(amountMinor: 7_500_000, date: now)
        context.insert(contribution)
        contribution.goal = goal

        try context.save()
    }
}
#endif

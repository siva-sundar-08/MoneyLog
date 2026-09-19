import Foundation
import Testing
import SwiftData
@testable import MoneyLog

// Shared helpers for the tests below.
//
// Everything here exists to make tests repeatable: a calendar pinned to UTC so a
// date test can't fail because the machine is in another time zone, and a store
// that lives in memory so tests never see — or damage — real data.
enum TestCalendar {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_IN")
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

extension Money {
    static func inr(_ rupees: Int64) -> Money { Money(minorUnits: rupees * 100, currency: .inr) }
}

// A brand-new database in memory, with the starter categories already in it.
// Each test gets its own, so tests can't interfere with each other.
@MainActor
struct TestStore {
    let container: ModelContainer
    let app: AppContainer

    init() throws {
        container = try PersistenceController.makeContainer(location: .inMemory)
        app = AppContainer(
            modelContainer: container,
            currency: FixedCurrencyProvider(currentCurrency: .inr),
            calendar: TestCalendar.utc
        )
        try SeedDataService(context: container.mainContext, currency: .inr).seedIfNeeded()
    }

    var context: ModelContext { container.mainContext }

    func cash() throws -> Account {
        try #require(try app.accounts.accounts(includeArchived: false).first)
    }

    func expenseCategory(_ key: String = "food") throws -> TransactionCategory {
        try #require(try app.categories.categories(of: .expense, includeArchived: false).first { $0.systemKey == key })
    }

    func incomeCategory() throws -> TransactionCategory {
        try #require(try app.categories.categories(of: .income, includeArchived: false).first)
    }
}

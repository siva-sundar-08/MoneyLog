import Foundation
import Observation
import SwiftData

// The box that holds everything the app needs: the database, and one repository
// per kind of record.
//
// It's built once at launch and handed down to the screens, so a view never has
// to create its own database connection. Swap the contents here and the whole app
// follows — which is exactly what previews and tests do.
@MainActor
@Observable
final class AppContainer {
    let modelContainer: ModelContainer
    let currency: any CurrencyProviding
    let periods: PeriodCalculator

    let transactions: any TransactionRepository
    let accounts: any AccountRepository
    let categories: any CategoryRepository
    let budgets: any BudgetRepository
    let goals: any SavingsGoalRepository
    let recurring: any RecurringTransactionRepository

    init(
        modelContainer: ModelContainer,
        currency: any CurrencyProviding = UserDefaultsCurrencyProvider(),
        calendar: Calendar = .current
    ) {
        let context = modelContainer.mainContext
        let periods = PeriodCalculator(calendar: calendar)

        self.modelContainer = modelContainer
        self.currency = currency
        self.periods = periods
        self.transactions = SwiftDataTransactionRepository(context: context, calendar: calendar)
        self.accounts = SwiftDataAccountRepository(context: context, currency: currency)
        self.categories = SwiftDataCategoryRepository(context: context)
        self.budgets = SwiftDataBudgetRepository(context: context, periods: periods)
        self.goals = SwiftDataSavingsGoalRepository(context: context)
        self.recurring = SwiftDataRecurringTransactionRepository(context: context, calendar: calendar)
    }

    private var context: ModelContext { modelContainer.mainContext }

    // Run at launch: add starter data if needed, then catch up repeating rules.
    func prepareForLaunch(now: Date = .now) throws {
        try SeedDataService(context: context, currency: currency.currentCurrency).seedIfNeeded()
        try processRecurring(now: now)
    }

    // Deletes everything and starts fresh. There's no undo, so ask first.
    func eraseAllData() throws {
        try DataResetService(context: context, currency: currency.currentCurrency).eraseAll()
    }

    func transactionCount() throws -> Int {
        try DataResetService(context: context, currency: currency.currentCurrency).countOfTransactions()
    }

    @discardableResult
    func processRecurring(now: Date = .now) throws -> Int {
        try RecurrenceEngine(context: context, calendar: periods.calendar).processDueRules(now: now)
    }
}

#if DEBUG
extension AppContainer {
    // A fake container full of sample data, for Xcode previews.
    static func preview() -> AppContainer {
        AppContainer(
            modelContainer: PreviewSampleData.makeContainer(),
            currency: FixedCurrencyProvider(currentCurrency: .inr)
        )
    }
}
#endif

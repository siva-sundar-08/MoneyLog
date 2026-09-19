import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense
    case income
    case transfer

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .expense: String(localized: "transactionType.expense", defaultValue: "Expense")
        case .income: String(localized: "transactionType.income", defaultValue: "Income")
        case .transfer: String(localized: "transactionType.transfer", defaultValue: "Transfer")
        }
    }

    // Expenses need an expense category, income needs an income category.
    // Transfers need neither — nothing is being spent or earned.
    var requiredCategoryType: CategoryType? {
        switch self {
        case .expense: .expense
        case .income: .income
        case .transfer: nil
        }
    }
}

enum AccountType: String, Codable, CaseIterable, Identifiable, Sendable {
    case cash
    case bank
    case creditCard
    case wallet
    case savings

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .cash: String(localized: "accountType.cash", defaultValue: "Cash")
        case .bank: String(localized: "accountType.bank", defaultValue: "Bank Account")
        case .creditCard: String(localized: "accountType.creditCard", defaultValue: "Credit Card")
        case .wallet: String(localized: "accountType.wallet", defaultValue: "Wallet")
        case .savings: String(localized: "accountType.savings", defaultValue: "Savings")
        }
    }

    var symbolName: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .creditCard: "creditcard"
        case .wallet: "wallet.bifold"
        case .savings: "archivebox"
        }
    }

    // A credit card balance is money you owe, not money you have.
    var isLiability: Bool { self == .creditCard }
}

enum CategoryType: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense
    case income

    var id: String { rawValue }
}

enum RecurringFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .daily: .day
        case .weekly, .biweekly: .weekOfYear
        case .monthly, .quarterly: .month
        case .yearly: .year
        }
    }

    var step: Int {
        switch self {
        case .daily, .weekly, .monthly, .yearly: 1
        case .biweekly: 2
        case .quarterly: 3
        }
    }

    var localizedName: String {
        switch self {
        case .daily: String(localized: "frequency.daily", defaultValue: "Daily")
        case .weekly: String(localized: "frequency.weekly", defaultValue: "Weekly")
        case .biweekly: String(localized: "frequency.biweekly", defaultValue: "Every 2 Weeks")
        case .monthly: String(localized: "frequency.monthly", defaultValue: "Monthly")
        case .quarterly: String(localized: "frequency.quarterly", defaultValue: "Quarterly")
        case .yearly: String(localized: "frequency.yearly", defaultValue: "Yearly")
        }
    }
}

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly
    case monthly

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly: .weekOfYear
        case .monthly: .month
        }
    }
}

// The name of a colour, not the colour itself.
//
// The database stores "terracotta"; the design system decides what terracotta
// actually looks like, and picks a different shade in dark mode. That means you
// can restyle the whole app without touching a single saved record.
enum TintKey: String, Codable, CaseIterable, Sendable {
    case teal, sage, sand, terracotta, plum, ochre, slate, rose, moss, indigo
}

import Foundation

// A stripped-down copy of a transaction: just the numbers needed for maths.
//
// The calculations below work on these instead of the database objects, which
// keeps them simple to test — no database required, just values in and out.
struct LedgerLine: Equatable, Sendable {
    let amountMinor: Int64
    let type: TransactionType
    let date: Date
    let accountID: UUID?
    let destinationAccountID: UUID?
    let categoryID: UUID?
}

struct CashFlowSummary: Equatable, Sendable {
    var incomeMinor: Int64 = 0
    var expenseMinor: Int64 = 0
    var netMinor: Int64 { incomeMinor - expenseMinor }

    // How much of what came in you kept, 0 to 1. Nil when there was no income.
    var savingsRate: Double? {
        guard incomeMinor > 0 else { return nil }
        return max(0, Double(netMinor) / Double(incomeMinor))
    }
}

// Works out balances by adding up transactions.
//
// We never store a balance anywhere. A stored number can quietly go wrong — a
// deleted transaction here, a missed update there — and then the app is lying.
// Adding it up every time is a little more work and always correct.
enum BalanceCalculator {
    // What one transaction does to one account: adds, subtracts, or nothing.
    static func delta(of line: LedgerLine, on accountID: UUID) -> Int64 {
        switch line.type {
        case .income:
            return line.accountID == accountID ? line.amountMinor : 0
        case .expense:
            return line.accountID == accountID ? -line.amountMinor : 0
        case .transfer:
            var delta: Int64 = 0
            if line.accountID == accountID { delta -= line.amountMinor }
            if line.destinationAccountID == accountID { delta += line.amountMinor }
            return delta
        }
    }

    // Every account's current balance: what it started with, plus everything since.
    static func balances(openingBalances: [UUID: Int64], lines: [LedgerLine]) -> [UUID: Int64] {
        var result = openingBalances
        for line in lines {
            switch line.type {
            case .income:
                if let id = line.accountID, result[id] != nil { result[id, default: 0] += line.amountMinor }
            case .expense:
                if let id = line.accountID, result[id] != nil { result[id, default: 0] -= line.amountMinor }
            case .transfer:
                if let id = line.accountID, result[id] != nil { result[id, default: 0] -= line.amountMinor }
                if let id = line.destinationAccountID, result[id] != nil { result[id, default: 0] += line.amountMinor }
            }
        }
        return result
    }

    // Totals for money in and money out.
    // Transfers are skipped: moving ₹500 from bank to wallet isn't income or
    // spending, and counting it as both would double your numbers.
    static func cashFlow(of lines: [LedgerLine]) -> CashFlowSummary {
        lines.reduce(into: CashFlowSummary()) { summary, line in
            switch line.type {
            case .income: summary.incomeMinor += line.amountMinor
            case .expense: summary.expenseMinor += line.amountMinor
            case .transfer: break
            }
        }
    }

    // How much was spent in each category.
    static func expensesByCategory(_ lines: [LedgerLine]) -> [UUID: Int64] {
        lines.reduce(into: [:]) { totals, line in
            guard line.type == .expense, let id = line.categoryID else { return }
            totals[id, default: 0] += line.amountMinor
        }
    }
}

#if DEBUG
import SwiftUI
import SwiftData

// A plain list of what's in the database: balances and row counts.
//
// Only built in debug (see the #if DEBUG wrapping this file) and only reachable
// from Settings while developing. Handy when a number on screen looks wrong and
// you want to know whether the data or the drawing is at fault.
struct FoundationStatusView: View {
    @Environment(AppContainer.self) private var container
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var categories: [TransactionCategory]
    @Query(sort: \TransactionRecord.date, order: .reverse) private var transactions: [TransactionRecord]

    @State private var balances: [UUID: Money] = [:]
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Accounts") {
                    ForEach(accounts) { account in
                        LabeledContent(account.name) {
                            Text(balances[account.id]?.formatted() ?? "—")
                                .monospacedDigit()
                        }
                    }
                }
                Section("Store") {
                    LabeledContent("Categories", value: categories.count, format: .number)
                    LabeledContent("Transactions", value: transactions.count, format: .number)
                }
                Section {
                    Button("Add sample expense", action: addSampleExpense)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("MoneyLog")
            .task(id: transactions.count) { refreshBalances() }
        }
    }

    private func refreshBalances() {
        do {
            balances = try container.accounts.balances()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addSampleExpense() {
        do {
            guard let account = accounts.first,
                  let category = try container.categories.categories(of: .expense, includeArchived: false).first
            else { return }
            let draft = TransactionDraft(
                amount: Money(minorUnits: 25_000, currency: container.currency.currentCurrency),
                type: .expense,
                accountID: account.id,
                categoryID: category.id,
                merchant: "Sample"
            )
            try container.transactions.create(draft)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    FoundationStatusView()
        .environment(container)
        .modelContainer(container.modelContainer)
}

#endif

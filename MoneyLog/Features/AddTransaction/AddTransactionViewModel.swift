import Foundation
import Observation

// Runs the Add (and Edit) transaction sheet: what's been typed, what's missing,
// and what happens when Save is pressed.
@MainActor
@Observable
final class AddTransactionViewModel {
    private(set) var type: TransactionType = .expense
    var entry: AmountEntry
    var selectedCategoryID: UUID?
    var selectedAccountID: UUID?
    var destinationAccountID: UUID?
    var date: Date = .now
    var merchant = ""
    var note = ""
    var isRecurring = false
    var frequency: RecurringFrequency = .monthly

    var errorMessage: String?
    var duplicateCandidate: TransactionRecord?
    var didSave = false

    private(set) var categories: [TransactionCategory] = []
    private(set) var recentCategories: [TransactionCategory] = []
    private(set) var accounts: [Account] = []
    private(set) var merchantSuggestions: [String] = []

    private let container: AppContainer
    // Empty when adding something new; set when editing an existing transaction.
    private let editing: TransactionRecord?

    init(container: AppContainer, editing: TransactionRecord? = nil) {
        self.container = container
        self.editing = editing
        self.entry = AmountEntry(currency: container.currency.currentCurrency)
    }

    var isEditing: Bool { editing != nil }

    var amount: Money { entry.money }
    var canSave: Bool { amount.minorUnits > 0 && selectedAccountID != nil && requiredTargetSelected }

    private var requiredTargetSelected: Bool {
        switch type {
        case .transfer: destinationAccountID != nil
        case .expense, .income: selectedCategoryID != nil
        }
    }

    // What still needs filling in, in the order a person would fix it.
    //
    // This exists because a greyed-out button that explains nothing is, from the
    // user's side, indistinguishable from a broken one.
    var missingRequirement: String? {
        if amount.minorUnits <= 0 {
            return String(localized: "add.needAmount", defaultValue: "Enter an amount first.")
        }
        if selectedAccountID == nil {
            return accounts.isEmpty
                ? String(localized: "add.needAccountSetup", defaultValue: "Add an account in Settings before recording anything.")
                : String(localized: "add.needAccount", defaultValue: "Choose an account.")
        }
        switch type {
        case .transfer:
            return destinationAccountID == nil
                ? String(localized: "add.needDestination", defaultValue: "Choose where the money is going.")
                : nil
        case .expense, .income:
            return selectedCategoryID == nil
                ? String(localized: "add.needCategory", defaultValue: "Pick a category to save this.")
                : nil
        }
    }

    // Save calls this whatever the state: it either saves, or says what's missing.
    func save() {
        guard canSave else {
            errorMessage = missingRequirement
            Haptics.play(.blocked)
            return
        }
        attemptSave()
    }

    var selectedCategory: TransactionCategory? {
        categories.first { $0.id == selectedCategoryID } ?? recentCategories.first { $0.id == selectedCategoryID }
    }

    // Which field is blocking Save, so the screen can open the right control.
    enum MissingField { case amount, account, destination, category }

    var missingField: MissingField? {
        if amount.minorUnits <= 0 { return .amount }
        if selectedAccountID == nil { return .account }
        switch type {
        case .transfer: return destinationAccountID == nil ? .destination : nil
        case .expense, .income: return selectedCategoryID == nil ? .category : nil
        }
    }

    func selectCategory(_ category: TransactionCategory) {
        selectedCategoryID = category.id
        errorMessage = nil
    }

    var selectedAccount: Account? { accounts.first { $0.id == selectedAccountID } }
    var destinationAccount: Account? { accounts.first { $0.id == destinationAccountID } }

    func load() {
        do {
            accounts = try container.accounts.accounts(includeArchived: false)
            merchantSuggestions = try container.transactions.recentMerchants(limit: 6)

            if let editing {
                prefill(from: editing)
            }
            selectedAccountID = selectedAccountID ?? accounts.first?.id
            reloadCategories()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prefill(from transaction: TransactionRecord) {
        type = transaction.type
        entry = AmountEntry(currency: transaction.currency, minorUnits: transaction.amountMinor)
        selectedAccountID = transaction.account?.id
        destinationAccountID = transaction.destinationAccount?.id
        selectedCategoryID = transaction.category?.id
        date = transaction.date
        merchant = transaction.merchant ?? ""
        note = transaction.note ?? ""
    }

    // Switching between expense and income clears the category: a salary category
    // makes no sense on a purchase, and leaving a stale one selected invites a
    // miscategorised entry.
    func updateType(_ newValue: TransactionType) {
        guard newValue != type else { return }
        type = newValue
        selectedCategoryID = nil
        destinationAccountID = nil
        errorMessage = nil
        reloadCategories()
    }

    private func reloadCategories() {
        guard type != .transfer else {
            categories = []
            recentCategories = []
            return
        }
        do {
            let categoryType: CategoryType = type == .income ? .income : .expense
            let recent = try container.categories.recentlyUsed(of: categoryType, limit: 4)
            let all = try container.categories.categories(of: categoryType, includeArchived: false)
            recentCategories = recent
            categories = all
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Saving

    // Looks for an accidental double-tap first — same amount, same shop, seconds
    // apart — and asks before saving a second copy.
    func attemptSave() {
        errorMessage = nil
        // Editing an existing row can't be a duplicate of itself.
        guard editing == nil else {
            commit(ignoringDuplicate: true)
            return
        }
        guard !isRecurring else {
            commit(ignoringDuplicate: true)
            return
        }
        do {
            if let duplicate = try container.transactions.possibleDuplicate(of: draft(), within: 120) {
                duplicateCandidate = duplicate
                return
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        commit(ignoringDuplicate: true)
    }

    func commit(ignoringDuplicate: Bool) {
        duplicateCandidate = nil
        do {
            if let editing {
                try container.transactions.update(editing, with: draft())
                Haptics.play(.saved)
                didSave = true
                return
            }
            if isRecurring {
                // The rule owns the schedule; the engine materialises today's occurrence.
                let rule = RecurringDraft(template: draft(), frequency: frequency, endDate: nil, remindDaysBefore: 1)
                try container.recurring.create(rule)
                try container.processRecurring()
            } else {
                try container.transactions.create(draft())
            }
            Haptics.play(.saved)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Delete from inside the edit sheet. The list behind it offers Undo.
    func deleteEditedTransaction() {
        guard let editing else { return }
        do {
            try container.transactions.delete(editing)
            Haptics.play(.deleted)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func draft() -> TransactionDraft {
        TransactionDraft(
            amount: amount,
            type: type,
            date: date,
            accountID: selectedAccountID,
            destinationAccountID: type == .transfer ? destinationAccountID : nil,
            categoryID: type == .transfer ? nil : selectedCategoryID,
            merchant: merchant,
            note: note
        )
    }
}

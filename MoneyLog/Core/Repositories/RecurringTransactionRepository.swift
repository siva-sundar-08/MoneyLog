import Foundation
import SwiftData

struct RecurringDraft: Equatable, Sendable {
    var template: TransactionDraft
    var frequency: RecurringFrequency
    var endDate: Date?
    var remindDaysBefore: Int?

    // The date on the template is when the first one happens.
    var startDate: Date { template.date }
}

@MainActor
protocol RecurringTransactionRepository: AnyObject {
    func rules(includePaused: Bool) throws -> [RecurringTransaction]
    func upcoming(within days: Int, from now: Date) throws -> [RecurringTransaction]
    @discardableResult func create(_ draft: RecurringDraft) throws -> RecurringTransaction
    func update(_ rule: RecurringTransaction, with draft: RecurringDraft) throws
    func setPaused(_ rule: RecurringTransaction, _ paused: Bool) throws
    // Removes the rule but keeps everything it already created. You stopped a
    // subscription; you didn't un-spend last month's money.
    func delete(_ rule: RecurringTransaction) throws
}

@MainActor
final class SwiftDataRecurringTransactionRepository: RecurringTransactionRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func rules(includePaused: Bool = true) throws -> [RecurringTransaction] {
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: includePaused ? nil : #Predicate { $0.isPaused == false },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetchOrThrow(descriptor).sorted {
            ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture)
        }
    }

    func upcoming(within days: Int, from now: Date = .now) throws -> [RecurringTransaction] {
        guard let horizon = calendar.date(byAdding: .day, value: days, to: now) else { return [] }
        return try rules(includePaused: false).filter {
            guard let due = $0.nextDueDate else { return false }
            return due <= horizon
        }
    }

    @discardableResult
    func create(_ draft: RecurringDraft) throws -> RecurringTransaction {
        let links = try validate(draft)
        let template = draft.template
        let rule = RecurringTransaction(
            amount: template.amount,
            type: template.type,
            frequency: draft.frequency,
            startDate: draft.startDate,
            endDate: draft.endDate,
            merchant: template.trimmedMerchant,
            note: template.trimmedNote,
            remindDaysBefore: draft.remindDaysBefore
        )
        context.insert(rule)
        rule.account = links.account
        rule.destinationAccount = links.destination
        rule.category = links.category
        try context.saveOrRollback()
        return rule
    }

    func update(_ rule: RecurringTransaction, with draft: RecurringDraft) throws {
        let links = try validate(draft)
        let template = draft.template
        let scheduleChanged = rule.startDate != draft.startDate || rule.frequency != draft.frequency

        rule.amount = template.amount
        rule.type = template.type
        rule.merchant = template.trimmedMerchant
        rule.note = template.trimmedNote
        rule.frequency = draft.frequency
        rule.startDate = draft.startDate
        rule.endDate = draft.endDate
        rule.remindDaysBefore = draft.remindDaysBefore
        rule.account = links.account
        rule.destinationAccount = links.destination
        rule.category = links.category

        // A new schedule restarts from its first occurrence that is still in the future,
        // so already-generated history is never duplicated.
        if scheduleChanged {
            let schedule = rule.schedule(calendar: calendar)
            let past = schedule.dueOccurrences(startingAt: 0, through: .now, limit: Int.max / 2)
            rule.occurrenceIndex = (past.last?.index ?? -1) + 1
        }
        rule.nextDueDate = rule.schedule(calendar: calendar).occurrence(at: rule.occurrenceIndex)
        try context.saveOrRollback()
    }

    func setPaused(_ rule: RecurringTransaction, _ paused: Bool) throws {
        rule.isPaused = paused
        try context.saveOrRollback()
    }

    func delete(_ rule: RecurringTransaction) throws {
        context.delete(rule)
        try context.saveOrRollback(operation: .delete)
    }

    private struct Links {
        let account: Account
        let destination: Account?
        let category: TransactionCategory?
    }

    private func validate(_ draft: RecurringDraft) throws -> Links {
        let template = draft.template
        // Recurring rules may start in the past (catch-up) or future; reuse structural checks.
        try TransactionValidator.validate(template, calendar: calendar)
        if let end = draft.endDate, end < draft.startDate { throw AppError.validation(.endBeforeStart) }

        guard let accountID = template.accountID, let account = try context.account(id: accountID) else {
            throw AppError.validation(.missingAccount)
        }
        guard account.currency == template.amount.currency else { throw AppError.validation(.currencyMismatch) }

        if template.type == .transfer {
            guard let id = template.destinationAccountID, let destination = try context.account(id: id) else {
                throw AppError.validation(.missingDestinationAccount)
            }
            return Links(account: account, destination: destination, category: nil)
        }

        guard let categoryID = template.categoryID, let category = try context.category(id: categoryID) else {
            throw AppError.validation(.missingCategory)
        }
        guard category.type == template.type.requiredCategoryType else {
            throw AppError.validation(.categoryTypeMismatch)
        }
        return Links(account: account, destination: nil, category: category)
    }
}

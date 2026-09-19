import Foundation
import SwiftData
import OSLog

// Turns repeating rules into real transactions once they fall due.
//
// Runs at launch and whenever the app comes back to the foreground, so if you
// don't open the app for three weeks, the rent entries you missed appear at once.
//
// Running it twice in a row is harmless: each rule remembers which repeat it has
// reached, and we double-check the day before adding anything.
@MainActor
struct RecurrenceEngine {
    // Safety net. A daily rule left alone for two years would otherwise try to
    // create 700 rows in one go; we stop well before the app feels frozen.
    static let maximumCatchUp = 400

    let context: ModelContext
    var calendar: Calendar = .current

    private let logger = Logger(subsystem: "com.wedzat.moneylog", category: "Recurrence")

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    // Returns how many transactions it created.
    @discardableResult
    func processDueRules(now: Date = .now) throws -> Int {
        let cutoff = now
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate { rule in
                rule.isPaused == false && rule.nextDueDate != nil
            }
        )

        let rules: [RecurringTransaction]
        do {
            rules = try context.fetch(descriptor).filter { ($0.nextDueDate ?? .distantFuture) <= cutoff }
        } catch {
            throw AppError.persistence(operation: .fetch, underlying: error.localizedDescription)
        }

        var created = 0
        for rule in rules {
            created += materialise(rule, through: cutoff)
        }

        guard context.hasChanges else { return created }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw AppError.persistence(operation: .save, underlying: error.localizedDescription)
        }
        if created > 0 { logger.info("Created \(created) recurring transactions") }
        return created
    }

    private func materialise(_ rule: RecurringTransaction, through now: Date) -> Int {
        // A rule whose source account was deleted can't produce valid entries; pause it
        // so the user sees it needs attention instead of silently skipping forever.
        guard let account = rule.account,
              rule.type != .transfer || rule.destinationAccount != nil
        else {
            rule.isPaused = true
            return 0
        }

        let schedule = rule.schedule(calendar: calendar)
        let existingDays = Set(rule.generatedTransactions.map { calendar.startOfDay(for: $0.date) })
        var created = 0

        for occurrence in schedule.dueOccurrences(startingAt: rule.occurrenceIndex, through: now, limit: Self.maximumCatchUp) {
            if !existingDays.contains(calendar.startOfDay(for: occurrence.date)) {
                let record = TransactionRecord(
                    amount: rule.amount,
                    type: rule.type,
                    date: occurrence.date,
                    merchant: rule.merchant,
                    note: rule.note
                )
                context.insert(record)
                record.account = account
                record.destinationAccount = rule.type == .transfer ? rule.destinationAccount : nil
                record.category = rule.type == .transfer ? nil : rule.category
                record.recurringRule = rule
                created += 1
            }
            rule.occurrenceIndex = occurrence.index + 1
        }

        rule.nextDueDate = schedule.occurrence(at: rule.occurrenceIndex)
        return created
    }
}

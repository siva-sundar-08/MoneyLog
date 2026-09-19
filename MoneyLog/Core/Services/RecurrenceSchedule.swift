import Foundation

// Works out the dates a repeating rule falls on. No database, just dates.
//
// Each date is measured from the original start date, never from the previous
// one. That sounds fussy until you try month-ends: starting 31 January, counting
// from the start gives 28 Feb then 31 Mar, which is what people expect. Counting
// from the previous date would give 28 Feb then 28 Mar, and your rent would
// slowly walk backwards through the month.
struct RecurrenceSchedule: Sendable {
    let start: Date
    let frequency: RecurringFrequency
    let end: Date?
    let calendar: Calendar

    struct Occurrence: Equatable, Sendable {
        let index: Int
        let date: Date
    }

    func occurrence(at index: Int) -> Date? {
        guard index >= 0,
              let date = calendar.date(
                byAdding: frequency.calendarComponent,
                value: frequency.step * index,
                to: start
              )
        else { return nil }
        if let end, date > end { return nil }
        return date
    }

    // Every date from `index` onwards that has already arrived, up to `limit` of them.
    func dueOccurrences(startingAt index: Int, through now: Date, limit: Int) -> [Occurrence] {
        var result: [Occurrence] = []
        var cursor = index
        while result.count < limit, let date = occurrence(at: cursor), date <= now {
            result.append(Occurrence(index: cursor, date: date))
            cursor += 1
        }
        return result
    }
}

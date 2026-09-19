import Foundation

// Date arithmetic: when does this month start, how many days are left, and so on.
//
// It takes a Calendar rather than using the global one so tests can pin it to a
// fixed time zone. Date maths that "works on my machine" and breaks in another
// time zone is a classic bug, and this is how you avoid it.
struct PeriodCalculator: Sendable {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func interval(of component: Calendar.Component, containing date: Date) -> DateInterval {
        calendar.dateInterval(of: component, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }

    func month(containing date: Date) -> DateInterval {
        interval(of: .month, containing: date)
    }

    func interval(for period: BudgetPeriod, containing date: Date) -> DateInterval {
        interval(of: period.calendarComponent, containing: date)
    }

    // The month (or week) just before the one this date falls in.
    func previous(_ component: Calendar.Component, before date: Date) -> DateInterval {
        let current = interval(of: component, containing: date)
        let probe = current.start.addingTimeInterval(-1)
        return interval(of: component, containing: probe)
    }

    // Every day in the range, as midnight dates — handy for drawing a bar per day.
    func days(in interval: DateInterval) -> [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: interval.start)
        while cursor < interval.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    // Days remaining, counting today. Zero once the period is over.
    func daysRemaining(in interval: DateInterval, from now: Date) -> Int {
        guard now < interval.end else { return 0 }
        let start = calendar.startOfDay(for: max(now, interval.start))
        let days = calendar.dateComponents([.day], from: start, to: interval.end).day ?? 0
        return max(days, 1)
    }

    // How far through the period we are, as 0 to 1.
    func elapsedFraction(of interval: DateInterval, at now: Date) -> Double {
        guard interval.duration > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(interval.start) / interval.duration
        return min(max(elapsed, 0), 1)
    }
}

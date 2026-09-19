import Foundation

struct BudgetStatus: Equatable, Sendable {
    enum Level: Equatable, Sendable {
        // Comfortably inside the limit.
        case onTrack
        // Close to the limit — past the warning line, but not over yet.
        case approaching
        // Over the limit.
        case over
    }

    let limitMinor: Int64
    let spentMinor: Int64
    // Spent divided by limit. Deliberately not capped: 1.25 means 25% over.
    let progress: Double
    // How far through the month we are, 0 to 1. On the 15th of a 30-day month
    // it's 0.5. This is what the little tick on the budget bar points at.
    let expectedProgress: Double
    let level: Level
    let daysRemaining: Int
    let period: DateInterval

    var remainingMinor: Int64 { limitMinor - spentMinor }
    var overspentMinor: Int64 { max(0, spentMinor - limitMinor) }

    // What you'd have spent by now if you were spreading it evenly.
    var expectedSpendMinor: Int64 { Int64((Double(limitMinor) * expectedProgress).rounded()) }

    // Positive means you're behind that pace, which is the good direction.
    var paceDeltaMinor: Int64 { expectedSpendMinor - spentMinor }

    // What's left, divided by the days left.
    var dailyAllowanceMinor: Int64 {
        guard remainingMinor > 0, daysRemaining > 0 else { return 0 }
        return remainingMinor / Int64(daysRemaining)
    }
}

enum BudgetCalculator {
    static func status(
        limitMinor: Int64,
        spentMinor: Int64,
        period: DateInterval,
        alertThreshold: Double,
        now: Date,
        periods: PeriodCalculator
    ) -> BudgetStatus {
        let progress: Double
        if limitMinor > 0 {
            progress = Double(spentMinor) / Double(limitMinor)
        } else {
            progress = spentMinor > 0 ? 1 : 0
        }

        let threshold = min(max(alertThreshold, 0.01), 1)
        let level: BudgetStatus.Level
        if spentMinor > limitMinor {
            level = .over
        } else if progress >= threshold {
            level = .approaching
        } else {
            level = .onTrack
        }

        return BudgetStatus(
            limitMinor: limitMinor,
            spentMinor: spentMinor,
            progress: progress,
            expectedProgress: periods.elapsedFraction(of: period, at: now),
            level: level,
            daysRemaining: periods.daysRemaining(in: period, from: now),
            period: period
        )
    }
}

struct GoalProgress: Equatable, Sendable {
    let savedMinor: Int64
    let targetMinor: Int64
    let targetDate: Date?
    let createdAt: Date

    var fraction: Double {
        guard targetMinor > 0 else { return 0 }
        return min(max(Double(savedMinor) / Double(targetMinor), 0), 1)
    }

    var remainingMinor: Int64 { max(0, targetMinor - savedMinor) }
    var isReached: Bool { targetMinor > 0 && savedMinor >= targetMinor }

    // How much a month it takes to get there in time. Nil if there's no target date.
    func requiredMonthlyMinor(now: Date, calendar: Calendar) -> Int64? {
        guard let targetDate, remainingMinor > 0 else { return nil }
        let months = calendar.dateComponents([.month], from: now, to: targetDate).month ?? 0
        return remainingMinor / Int64(max(months, 1))
    }
}

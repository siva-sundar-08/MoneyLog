import SwiftUI

// The cards that make up the home screen, in the order they appear: balance,
// this month's totals, budget progress, accounts, savings goal, recent activity.
//
// They're split out from TodayView so that file stays a readable summary of the
// layout instead of a thousand-line wall.

// MARK: - Balance

struct BalanceCard: View {
    let snapshot: DashboardSnapshot
    let insight: String

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                MicroLabel(String(localized: "dashboard.totalBalance", defaultValue: "Total balance"))

                AmountText(money: snapshot.netWorth, size: .hero)

                Text(insight)
                    .font(Typography.insightSerif)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Month pulse

struct MonthPulseCard: View {
    let snapshot: DashboardSnapshot
    let monthName: String

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    MicroLabel(monthName)
                    Spacer()
                    Text(comparisonText)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }

                HStack(alignment: .top, spacing: Spacing.m) {
                    pulseColumn(
                        label: String(localized: "dashboard.in", defaultValue: "In"),
                        money: snapshot.monthIncome,
                        color: Palette.income
                    )
                    Divider().frame(height: 34)
                    pulseColumn(
                        label: String(localized: "dashboard.out", defaultValue: "Out"),
                        money: snapshot.monthExpense,
                        color: Palette.ink
                    )
                    Divider().frame(height: 34)
                    pulseColumn(
                        label: String(localized: "dashboard.net", defaultValue: "Net"),
                        money: snapshot.monthNet,
                        color: snapshot.monthNet.isNegative ? Palette.over : Palette.income,
                        showsPlusSign: true
                    )
                }

                MonthRibbon(
                    days: snapshot.dailySpend,
                    currency: snapshot.currency,
                    todayIndex: snapshot.todayIndex
                )
            }
        }
    }

    private func pulseColumn(label: String, money: Money, color: Color, showsPlusSign: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            MicroLabel(label)
            AmountText(money: money, size: .title, color: color, showsPlusSign: showsPlusSign)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comparisonText: String {
        let current = snapshot.monthExpense.minorUnits
        let previous = snapshot.previousMonthExpense.minorUnits
        guard previous > 0 else {
            return String(localized: "dashboard.noComparison", defaultValue: "First month")
        }
        let change = Double(current - previous) / Double(previous)
        let percent = abs(change).formatted(.percent.precision(.fractionLength(0)))
        let direction = change >= 0
            ? String(localized: "dashboard.above", defaultValue: "above")
            : String(localized: "dashboard.below", defaultValue: "below")
        return String(localized: "dashboard.vsLastMonth", defaultValue: "\(percent) \(direction) last month")
    }
}

// MARK: - Budget pace

struct BudgetPaceCard: View {
    let budget: BudgetSummary
    let currency: CurrencyCode

    private var status: BudgetStatus { budget.status }

    private var color: Color {
        switch status.level {
        case .onTrack: Palette.accent
        case .approaching: Palette.caution
        case .over: Palette.over
        }
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    MicroLabel(budget.isOverall
                               ? String(localized: "dashboard.monthlyBudget", defaultValue: "Monthly budget")
                               : budget.name)
                    Spacer()
                    Text(status.level == .over ? overText : remainingText)
                        .font(Typography.caption)
                        .foregroundStyle(color)
                }

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    AmountText(money: Money(minorUnits: status.spentMinor, currency: currency), size: .title)
                    Text(String(localized: "dashboard.ofLimit", defaultValue: "of \(budget.limit.formatted())"))
                        .font(Typography.callout)
                        .foregroundStyle(Palette.inkTertiary)
                }

                PaceBar(
                    progress: status.progress,
                    expectedProgress: status.expectedProgress,
                    color: color
                )

                Text(footnote)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }

    private var remainingText: String {
        let remaining = Money(minorUnits: max(status.remainingMinor, 0), currency: currency)
        return String(localized: "dashboard.left", defaultValue: "\(remaining.formatted()) left")
    }

    private var overText: String {
        let over = Money(minorUnits: status.overspentMinor, currency: currency)
        return String(localized: "dashboard.over", defaultValue: "\(over.formatted()) over")
    }

    private var footnote: String {
        guard status.level != .over else {
            return String(localized: "dashboard.overFootnote", defaultValue: "Adjust the limit, or let it ride to next month.")
        }
        let daily = Money(minorUnits: status.dailyAllowanceMinor, currency: currency)
        return String(localized: "dashboard.dailyAllowance", defaultValue: "\(daily.formatted()) a day for \(status.daysRemaining) more days")
    }
}

// MARK: - Accounts

struct AccountsStrip: View {
    let accounts: [AccountSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader(String(localized: "dashboard.accounts", defaultValue: "Accounts"))

            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s) {
                    ForEach(accounts) { account in
                        AccountChip(account: account)
                    }
                }
                .padding(.horizontal, Spacing.xxs)
                .padding(.vertical, Spacing.xxs)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct AccountChip: View {
    let account: AccountSummary
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            CategoryGlyph(symbolName: account.type.symbolName, tint: account.tint, size: .small)

            Text(account.name)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)

            AmountText(
                money: account.balance,
                size: .body,
                color: account.balance.isNegative ? Palette.over : Palette.ink
            )
        }
        .padding(Spacing.s)
        .frame(width: 150, alignment: .leading)
        .background(Palette.surface)
        .cardShape(Radius.control)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(Elevation.shadowOpacity(for: scheme)), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Goal

struct GoalCard: View {
    let goal: GoalSummary

    var body: some View {
        AppCard {
            HStack(spacing: Spacing.m) {
                ZStack {
                    ProgressRing(progress: goal.progress.fraction, lineWidth: 8, color: Palette.tint(goal.tint))
                        .frame(width: 64, height: 64)
                    Image(systemName: goal.symbolName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Palette.tint(goal.tint))
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    MicroLabel(String(localized: "dashboard.goal", defaultValue: "Savings goal"))
                    Text(goal.name)
                        .font(Typography.headline)
                        .foregroundStyle(Palette.ink)
                    Text(progressText)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }

                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var progressText: String {
        let percent = goal.progress.fraction.formatted(.percent.precision(.fractionLength(0)))
        return String(localized: "dashboard.goalProgress", defaultValue: "\(goal.saved.formatted()) of \(goal.target.formatted()) · \(percent)")
    }
}

// MARK: - Recent

struct RecentTransactionsCard: View {
    let transactions: [TransactionRecord]
    let onSeeAll: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader(title: String(localized: "dashboard.recent", defaultValue: "Recent")) {
                if !transactions.isEmpty {
                    Button(String(localized: "action.seeAll", defaultValue: "See all"), action: onSeeAll)
                        .font(Typography.caption.weight(.medium))
                        .foregroundStyle(Palette.accent)
                }
            }

            AppCard(padding: Spacing.m) {
                if transactions.isEmpty {
                    EmptyState(
                        symbolName: "tray",
                        title: String(localized: "empty.transactions.title", defaultValue: "Nothing recorded yet"),
                        message: String(localized: "empty.transactions.message", defaultValue: "Log what you spent today and MoneyLog starts drawing the picture."),
                        actionTitle: String(localized: "action.addFirst", defaultValue: "Add an expense"),
                        action: onAdd
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                            TransactionRow(transaction: transaction, showsDate: true)
                            if index < transactions.count - 1 {
                                Divider().overlay(Palette.hairline)
                            }
                        }
                    }
                }
            }
        }
    }
}

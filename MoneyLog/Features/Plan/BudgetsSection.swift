import SwiftUI

// The budgets half of the Plan tab: one big ring for the overall budget, then a
// row per category budget.
struct BudgetsSection: View {
    let model: PlanViewModel
    let onCreate: () -> Void
    let onEdit: (Budget) -> Void

    var body: some View {
        if model.budgetRows.isEmpty {
            AppCard {
                EmptyState(
                    symbolName: "target",
                    title: String(localized: "empty.budgets.title", defaultValue: "No limits set"),
                    message: String(localized: "empty.budgets.message", defaultValue: "A monthly limit turns spending into something you can steer, not just watch."),
                    actionTitle: String(localized: "empty.budgets.action", defaultValue: "Set a budget"),
                    action: onCreate
                )
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if let overall = model.overallRow {
                    OverallBudgetCard(row: overall, currency: model.currency)
                        .onTapGesture { onEdit(overall.budget) }
                        .reveal(0)
                }

                if !model.categoryRows.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        SectionHeader(String(localized: "plan.byCategory", defaultValue: "By category"))

                        AppCard(padding: Spacing.m) {
                            VStack(spacing: Spacing.m) {
                                ForEach(Array(model.categoryRows.enumerated()), id: \.element.id) { index, row in
                                    CategoryBudgetRow(row: row, currency: model.currency)
                                        .contentShape(.rect)
                                        .onTapGesture { onEdit(row.budget) }

                                    if index < model.categoryRows.count - 1 {
                                        Divider().overlay(Palette.hairline)
                                    }
                                }
                            }
                        }
                    }
                    .reveal(1)
                }
            }
        }
    }
}

// MARK: - Overall

private struct OverallBudgetCard: View {
    let row: PlanViewModel.BudgetRow
    let currency: CurrencyCode

    private var status: BudgetStatus { row.status }

    private var color: Color {
        switch status.level {
        case .onTrack: Palette.accent
        case .approaching: Palette.caution
        case .over: Palette.over
        }
    }

    var body: some View {
        AppCard {
            HStack(spacing: Spacing.l) {
                ZStack {
                    ProgressRing(progress: status.progress, lineWidth: 10, color: color)
                        .frame(width: 92, height: 92)

                    VStack(spacing: 0) {
                        Text(status.progress.formatted(.percent.precision(.fractionLength(0))))
                            .font(Typography.amountTitle)
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                        Text(String(localized: "plan.used", defaultValue: "used"))
                            .font(Typography.micro)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    MicroLabel(row.budget.name)

                    AmountText(
                        money: Money(minorUnits: max(status.remainingMinor, 0), currency: currency),
                        size: .hero,
                        color: color
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                    Text(footnote)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var footnote: String {
        if status.level == .over {
            let over = Money(minorUnits: status.overspentMinor, currency: currency)
            return String(localized: "plan.overBy", defaultValue: "\(over.formatted()) over, \(status.daysRemaining) days left")
        }
        // Rounded: a daily allowance to the paise reads like false precision.
        let daily = Money(minorUnits: status.dailyAllowanceMinor, currency: currency).formatted(.never)
        return String(localized: "plan.leftOf", defaultValue: "left of \(Money(minorUnits: status.limitMinor, currency: currency).formatted()) · \(daily)/day")
    }
}

// MARK: - Category row

private struct CategoryBudgetRow: View {
    let row: PlanViewModel.BudgetRow
    let currency: CurrencyCode

    private var status: BudgetStatus { row.status }

    private var color: Color {
        switch status.level {
        case .onTrack: Palette.accent
        case .approaching: Palette.caution
        case .over: Palette.over
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                if let category = row.budget.category {
                    CategoryGlyph(symbolName: category.symbolName, tint: category.tint, size: .small)
                }

                Text(row.budget.name)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Spacer(minLength: Spacing.xs)

                AmountText(money: Money(minorUnits: status.spentMinor, currency: currency), size: .body)
                Text(String(localized: "plan.ofLimit", defaultValue: "/ \(Money(minorUnits: status.limitMinor, currency: currency).formatted())"))
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }

            PaceBar(progress: status.progress, expectedProgress: status.expectedProgress, color: color, height: 8)

            Text(paceText)
                .font(Typography.caption)
                .foregroundStyle(status.level == .over ? Palette.over : Palette.inkTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(paceText)
    }

    private var paceText: String {
        switch status.level {
        case .over:
            let over = Money(minorUnits: status.overspentMinor, currency: currency)
            return String(localized: "plan.pace.over", defaultValue: "\(over.formatted()) over")
        default:
            let delta = Money(minorUnits: abs(status.paceDeltaMinor), currency: currency)
            return status.paceDeltaMinor >= 0
                ? String(localized: "plan.pace.under", defaultValue: "\(delta.formatted()) under pace")
                : String(localized: "plan.pace.ahead", defaultValue: "\(delta.formatted()) ahead of pace")
        }
    }
}

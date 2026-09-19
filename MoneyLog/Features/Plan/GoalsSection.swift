import SwiftUI

// The savings-goals half of the Plan tab: one card per goal.
struct GoalsSection: View {
    let model: PlanViewModel
    let onCreate: () -> Void
    let onEdit: (SavingsGoal) -> Void
    let onContribute: (SavingsGoal) -> Void

    var body: some View {
        if model.goalRows.isEmpty {
            AppCard {
                EmptyState(
                    symbolName: "flag",
                    title: String(localized: "empty.goals.title", defaultValue: "Nothing saved for yet"),
                    message: String(localized: "empty.goals.message", defaultValue: "Name something worth saving for — a MacBook, a trip, a rainy-day fund — and watch it fill."),
                    actionTitle: String(localized: "empty.goals.action", defaultValue: "Create a goal"),
                    action: onCreate
                )
            }
        } else {
            VStack(spacing: Spacing.m) {
                ForEach(Array(model.goalRows.enumerated()), id: \.element.id) { index, row in
                    GoalCardView(
                        row: row,
                        currency: model.currency,
                        isCelebrating: model.celebratingGoalID == row.id,
                        onEdit: { onEdit(row.goal) },
                        onContribute: { onContribute(row.goal) }
                    )
                    .reveal(index)
                }
            }
        }
    }
}

private struct GoalCardView: View {
    let row: PlanViewModel.GoalRow
    let currency: CurrencyCode
    let isCelebrating: Bool
    let onEdit: () -> Void
    let onContribute: () -> Void

    private var goal: SavingsGoal { row.goal }
    private var tint: Color { Palette.tint(goal.tint) }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(spacing: Spacing.m) {
                    ZStack {
                        ProgressRing(progress: row.progress.fraction, lineWidth: 8, color: tint)
                            .frame(width: 66, height: 66)

                        Image(systemName: goal.isCompleted ? "checkmark" : goal.symbolName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(tint)
                            .symbolEffect(.bounce, value: isCelebrating)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.name)
                            .font(Typography.headline)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)

                        HStack(spacing: Spacing.xxs) {
                            AmountText(money: row.progress.savedMoney(currency), size: .body, color: tint)
                            Text(String(localized: "plan.ofTarget", defaultValue: "of \(Money(minorUnits: row.progress.targetMinor, currency: currency).formatted())"))
                                .font(Typography.caption)
                                .foregroundStyle(Palette.inkTertiary)
                        }

                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkTertiary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: Spacing.s) {
                    Button(action: onContribute) {
                        Label(
                            goal.isCompleted
                                ? String(localized: "plan.addMore", defaultValue: "Add more")
                                : String(localized: "plan.addMoney", defaultValue: "Add money"),
                            systemImage: "plus"
                        )
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(String(localized: "action.edit", defaultValue: "Edit"), action: onEdit)
                        .font(Typography.caption.weight(.medium))
                        .foregroundStyle(Palette.inkSecondary)
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)

                    Spacer()
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var subtitle: String {
        if goal.isCompleted {
            return String(localized: "plan.goalDone", defaultValue: "Reached — nicely done.")
        }
        let remaining = Money(minorUnits: row.progress.remainingMinor, currency: currency)
        if let targetDate = goal.targetDate, let monthly = row.requiredMonthlyMinor {
            let monthlyMoney = Money(minorUnits: monthly, currency: currency)
            let dateText = targetDate.formatted(.dateTime.month(.abbreviated).year())
            return String(localized: "plan.goalPace", defaultValue: "\(remaining.formatted()) to go · \(monthlyMoney.formatted())/month to reach \(dateText)")
        }
        return String(localized: "plan.goalRemaining", defaultValue: "\(remaining.formatted()) to go")
    }
}

extension GoalProgress {
    func savedMoney(_ currency: CurrencyCode) -> Money {
        Money(minorUnits: savedMinor, currency: currency)
    }
}

import SwiftUI

// MARK: - Budget editor

struct BudgetEditorView: View {
    var editing: Budget?
    let currency: CurrencyCode
    let categories: [TransactionCategory]
    // Returns nil when the save worked, or the reason it didn't.
    //
    // The sheet needs to know, because a failed save has to keep the sheet open and
    // show the reason — closing it and dropping the user's typing would be worse.
    let onSave: (BudgetDraft) -> String?
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var limitMinor: Int64 = 0
    @State private var period: BudgetPeriod = .monthly
    @State private var categoryID: UUID?
    @State private var threshold: Double = 0.8
    @State private var rollsOver = false
    @State private var isConfirmingDelete = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(spacing: Spacing.m) {
                        AppCard(padding: Spacing.m) {
                            VStack(spacing: Spacing.s) {
                                EditorRow(label: String(localized: "editor.limit", defaultValue: "Limit"), systemImage: "target") {
                                    MoneyField(currency: currency, minorUnits: $limitMinor)
                                }
                                Divider().overlay(Palette.hairline)

                                EditorRow(label: String(localized: "editor.applies", defaultValue: "Applies to"), systemImage: "square.grid.2x2") {
                                    Picker("", selection: $categoryID) {
                                        Text(String(localized: "editor.everything", defaultValue: "Everything")).tag(UUID?.none)
                                        ForEach(categories) { category in
                                            Text(category.name).tag(UUID?.some(category.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .tint(Palette.accent)
                                }
                                Divider().overlay(Palette.hairline)

                                EditorRow(label: String(localized: "editor.period", defaultValue: "Period"), systemImage: "calendar") {
                                    Picker("", selection: $period) {
                                        Text(String(localized: "period.monthly", defaultValue: "Monthly")).tag(BudgetPeriod.monthly)
                                        Text(String(localized: "period.weekly", defaultValue: "Weekly")).tag(BudgetPeriod.weekly)
                                    }
                                    .labelsHidden()
                                    .tint(Palette.accent)
                                }

                                if categoryID == nil {
                                    Divider().overlay(Palette.hairline)
                                    EditorRow(label: String(localized: "editor.name", defaultValue: "Name"), systemImage: "textformat") {
                                        TextField(String(localized: "editor.namePlaceholder", defaultValue: "Monthly"), text: $name)
                                            .multilineTextAlignment(.trailing)
                                            .font(Typography.body)
                                    }
                                }
                            }
                        }

                        AppCard(padding: Spacing.m) {
                            VStack(alignment: .leading, spacing: Spacing.s) {
                                HStack {
                                    Text(String(localized: "editor.warnAt", defaultValue: "Warn me at"))
                                        .font(Typography.callout)
                                        .foregroundStyle(Palette.inkSecondary)
                                    Spacer()
                                    Text(threshold.formatted(.percent.precision(.fractionLength(0))))
                                        .font(Typography.amountBody)
                                        .monospacedDigit()
                                        .foregroundStyle(Palette.ink)
                                }

                                Slider(value: $threshold, in: 0.5...1, step: 0.05)
                                    .tint(Palette.accent)

                                Divider().overlay(Palette.hairline)

                                Toggle(isOn: $rollsOver) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(String(localized: "editor.rollover", defaultValue: "Carry leftovers forward"))
                                            .font(Typography.callout)
                                            .foregroundStyle(Palette.inkSecondary)
                                        Text(String(localized: "editor.rolloverNote", defaultValue: "Anything unspent is added to next period."))
                                            .font(Typography.caption)
                                            .foregroundStyle(Palette.inkTertiary)
                                    }
                                }
                                .tint(Palette.accent)
                            }
                        }

                        if let saveError {
                            InlineErrorBanner(message: saveError)
                        }

                        if onDelete != nil {
                            Button(role: .destructive) {
                                isConfirmingDelete = true
                            } label: {
                                Label(String(localized: "editor.deleteBudget", defaultValue: "Delete budget"), systemImage: "trash")
                                    .font(Typography.callout)
                                    .foregroundStyle(Palette.over)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Spacing.s)
                            }
                            .background(Palette.over.opacity(0.08))
                            .cardShape(Radius.control)
                        }
                    }
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.vertical, Spacing.m)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(editing == nil ? "New Budget" : "Edit Budget"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save", defaultValue: "Save"), action: save)
                        .fontWeight(.semibold)
                        .disabled(limitMinor <= 0)
                }
            }
            .confirmationDialog(
                Text("Delete this budget?"),
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button(String(localized: "action.delete", defaultValue: "Delete"), role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "editor.deleteBudgetNote", defaultValue: "Your transactions stay exactly as they are."))
            }
        }
        .onAppear(perform: prefill)
    }

    private func prefill() {
        guard let editing else { return }
        name = editing.name
        limitMinor = editing.limitMinor
        period = editing.period
        categoryID = editing.category?.id
        threshold = editing.alertThreshold
        rollsOver = editing.rollsOver
    }

    private func save() {
        // An overall budget still needs a label; the placeholder is the sensible default.
        let resolvedName = name.trimmedNilIfEmpty
            ?? (categoryID == nil ? String(localized: "editor.namePlaceholder", defaultValue: "Monthly") : "")
        let draft = BudgetDraft(
            name: resolvedName,
            limit: Money(minorUnits: limitMinor, currency: currency),
            period: period,
            categoryID: categoryID,
            alertThreshold: threshold,
            rollsOver: rollsOver
        )
        if let message = onSave(draft) {
            withAnimation(Motion.layout) { saveError = message }
        } else {
            Haptics.play(.saved)
            dismiss()
        }
    }
}

// MARK: - Goal editor

struct GoalEditorView: View {
    var editing: SavingsGoal?
    let currency: CurrencyCode
    let accounts: [Account]
    let onSave: (SavingsGoalDraft) -> String?
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var saveError: String?

    private static let symbols = [
        "laptopcomputer", "airplane", "house", "car", "graduationcap",
        "gift", "heart", "camera", "bicycle", "umbrella", "star", "leaf",
    ]

    @State private var name = ""
    @State private var symbolName = "star"
    @State private var tint: TintKey = .teal
    @State private var targetMinor: Int64 = 0
    @State private var hasTargetDate = false
    @State private var targetDate = Date.now.addingTimeInterval(60 * 60 * 24 * 180)
    @State private var linkedAccountID: UUID?
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView {
                    VStack(spacing: Spacing.m) {
                        AppCard(padding: Spacing.m) {
                            VStack(spacing: Spacing.s) {
                                EditorRow(label: String(localized: "editor.name", defaultValue: "Name"), systemImage: "textformat") {
                                    TextField(String(localized: "editor.goalPlaceholder", defaultValue: "New MacBook"), text: $name)
                                        .multilineTextAlignment(.trailing)
                                        .font(Typography.body)
                                }
                                Divider().overlay(Palette.hairline)

                                EditorRow(label: String(localized: "editor.target", defaultValue: "Target"), systemImage: "target") {
                                    MoneyField(currency: currency, minorUnits: $targetMinor)
                                }
                                Divider().overlay(Palette.hairline)

                                Toggle(isOn: $hasTargetDate.animation(Motion.layout)) {
                                    Text(String(localized: "editor.byDate", defaultValue: "Reach it by"))
                                        .font(Typography.callout)
                                        .foregroundStyle(Palette.inkSecondary)
                                }
                                .tint(Palette.accent)

                                if hasTargetDate {
                                    DatePicker(
                                        selection: $targetDate,
                                        in: Date.now...,
                                        displayedComponents: .date
                                    ) {
                                        Text(String(localized: "editor.date", defaultValue: "Date"))
                                            .font(Typography.callout)
                                            .foregroundStyle(Palette.inkSecondary)
                                    }
                                    .tint(Palette.accent)
                                }

                                Divider().overlay(Palette.hairline)

                                EditorRow(label: String(localized: "editor.account", defaultValue: "Saved in"), systemImage: "wallet.bifold") {
                                    Picker("", selection: $linkedAccountID) {
                                        Text(String(localized: "editor.noAccount", defaultValue: "Not linked")).tag(UUID?.none)
                                        ForEach(accounts) { account in
                                            Text(account.name).tag(UUID?.some(account.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .tint(Palette.accent)
                                }
                            }
                        }

                        AppCard(padding: Spacing.m) {
                            VStack(alignment: .leading, spacing: Spacing.s) {
                                MicroLabel(String(localized: "editor.look", defaultValue: "Look"))

                                ScrollView(.horizontal) {
                                    HStack(spacing: Spacing.s) {
                                        ForEach(Self.symbols, id: \.self) { symbol in
                                            Button {
                                                withAnimation(Motion.select) { symbolName = symbol }
                                                Haptics.play(.categorySelected)
                                            } label: {
                                                CategoryGlyph(
                                                    symbolName: symbol,
                                                    tint: tint,
                                                    size: .medium,
                                                    isSelected: symbolName == symbol
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(Text(symbol))
                                            .accessibilityAddTraits(symbolName == symbol ? [.isSelected] : [])
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                                .scrollIndicators(.hidden)

                                ScrollView(.horizontal) {
                                    HStack(spacing: Spacing.s) {
                                        ForEach(TintKey.allCases, id: \.self) { option in
                                            Button {
                                                withAnimation(Motion.select) { tint = option }
                                            } label: {
                                                Circle()
                                                    .fill(Palette.tint(option))
                                                    .frame(width: 26, height: 26)
                                                    .overlay {
                                                        Circle()
                                                            .strokeBorder(Palette.ink.opacity(tint == option ? 0.6 : 0), lineWidth: 2)
                                                            .padding(-3)
                                                    }
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(Text(option.rawValue))
                                            .accessibilityAddTraits(tint == option ? [.isSelected] : [])
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .scrollIndicators(.hidden)
                            }
                        }

                        if let saveError {
                            InlineErrorBanner(message: saveError)
                        }

                        if onDelete != nil {
                            Button(role: .destructive) {
                                isConfirmingDelete = true
                            } label: {
                                Label(String(localized: "editor.deleteGoal", defaultValue: "Delete goal"), systemImage: "trash")
                                    .font(Typography.callout)
                                    .foregroundStyle(Palette.over)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Spacing.s)
                            }
                            .background(Palette.over.opacity(0.08))
                            .cardShape(Radius.control)
                        }
                    }
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.vertical, Spacing.m)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(editing == nil ? "New Goal" : "Edit Goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save", defaultValue: "Save"), action: save)
                        .fontWeight(.semibold)
                        .disabled(targetMinor <= 0 || name.trimmedNilIfEmpty == nil)
                }
            }
            .confirmationDialog(
                Text("Delete this goal?"),
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button(String(localized: "action.delete", defaultValue: "Delete"), role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "editor.deleteGoalNote", defaultValue: "The goal and its contribution history are removed."))
            }
        }
        .onAppear(perform: prefill)
    }

    private func prefill() {
        guard let editing else { return }
        name = editing.name
        symbolName = editing.symbolName
        tint = editing.tint
        targetMinor = editing.targetMinor
        if let date = editing.targetDate {
            hasTargetDate = true
            targetDate = date
        }
        linkedAccountID = editing.linkedAccount?.id
    }

    private func save() {
        let draft = SavingsGoalDraft(
            name: name,
            symbolName: symbolName,
            tint: tint,
            target: Money(minorUnits: targetMinor, currency: currency),
            targetDate: hasTargetDate ? targetDate : nil,
            linkedAccountID: linkedAccountID
        )
        if let message = onSave(draft) {
            withAnimation(Motion.layout) { saveError = message }
        } else {
            Haptics.play(.saved)
            dismiss()
        }
    }
}

// MARK: - Contribution

struct ContributionSheet: View {
    let goal: SavingsGoal
    let currency: CurrencyCode
    let onAdd: (Money, String?) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var amountMinor: Int64 = 0
    @State private var note = ""
    @State private var isWithdrawal = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                VStack(spacing: Spacing.m) {
                    AppCard(padding: Spacing.m) {
                        VStack(spacing: Spacing.s) {
                            Picker("", selection: $isWithdrawal) {
                                Text(String(localized: "contribution.add", defaultValue: "Add")).tag(false)
                                Text(String(localized: "contribution.take", defaultValue: "Take out")).tag(true)
                            }
                            .pickerStyle(.segmented)

                            EditorRow(label: String(localized: "contribution.amount", defaultValue: "Amount"), systemImage: "indianrupeesign") {
                                MoneyField(currency: currency, minorUnits: $amountMinor)
                            }

                            Divider().overlay(Palette.hairline)

                            EditorRow(label: String(localized: "contribution.note", defaultValue: "Note"), systemImage: "text.alignleft") {
                                TextField(String(localized: "contribution.optional", defaultValue: "Optional"), text: $note)
                                    .multilineTextAlignment(.trailing)
                                    .font(Typography.body)
                            }
                        }
                    }

                    Text(String(localized: "contribution.explain", defaultValue: "This records progress towards “\(goal.name)”. It doesn't move money between accounts."))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkTertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Spacing.m)

                    if let saveError {
                        InlineErrorBanner(message: saveError)
                    }

                    Spacer()

                    Button(action: submit) {
                        Text(isWithdrawal
                             ? String(localized: "contribution.takeAction", defaultValue: "Take out")
                             : String(localized: "contribution.addAction", defaultValue: "Add to goal"))
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: amountMinor > 0))
                    .disabled(amountMinor <= 0)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.m)
            }
            .navigationTitle(Text(goal.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func submit() {
        let signed = isWithdrawal ? -amountMinor : amountMinor
        if let message = onAdd(Money(minorUnits: signed, currency: currency), note.trimmedNilIfEmpty) {
            withAnimation(Motion.layout) { saveError = message }
        } else {
            dismiss()
        }
    }
}

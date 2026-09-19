import SwiftUI

struct AddTransactionView: View {
    // Empty when adding; set when editing an existing transaction.
    var editing: TransactionRecord? = nil

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var model: AddTransactionViewModel?
    @State private var isPickingCategory = false
    @FocusState fileprivate var focusedField: Field?

    fileprivate enum Field: Hashable { case merchant, note }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()
                if let model {
                    content(model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(Text(editing == nil ? "New Transaction" : "Edit Transaction"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
                if editing != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            model?.deleteEditedTransaction()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(Palette.over)
                        .accessibilityLabel(Text("Delete transaction"))
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "action.done", defaultValue: "Done")) { focusedField = nil }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .task {
            if model == nil {
                let model = AddTransactionViewModel(container: container, editing: editing)
                model.load()
                self.model = model
            }
        }
    }

    @ViewBuilder
    private func content(_ model: AddTransactionViewModel) -> some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.m) {
                    TypeSelector(type: Binding(get: { model.type }, set: { model.updateType($0) }))
                    AmountDisplay(entry: model.entry)

                    if model.type == .transfer {
                        TransferPicker(model: model)
                    } else {
                        CategoryField(
                            category: model.selectedCategory,
                            isMissing: model.errorMessage != nil && model.selectedCategoryID == nil
                        ) {
                            isPickingCategory = true
                        }
                    }

                    DetailsCard(model: model, focusedField: $focusedField)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.m)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            if let errorMessage = model.errorMessage {
                InlineErrorBanner(message: errorMessage)
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.bottom, Spacing.xs)
                    .transition(.opacity)
            }

            AmountKeypad(
                entry: $model.entry,
                onSave: {
                    // A missing category isn't an error to report — it's a picker to open.
                    if model.missingField == .category {
                        isPickingCategory = true
                    } else {
                        model.save()
                    }
                },
                canSave: model.canSave
            )
        }
        .animation(Motion.layout, value: focusedField)
        .animation(Motion.layout, value: model.errorMessage)
        .animation(Motion.select, value: model.type)
        .confirmationDialog(
            Text("Possible duplicate"),
            isPresented: .init(
                get: { model.duplicateCandidate != nil },
                set: { if !$0 { model.duplicateCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "add.duplicate.save", defaultValue: "Save anyway")) {
                model.commit(ignoringDuplicate: true)
            }
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {
                model.duplicateCandidate = nil
            }
        } message: {
            Text(String(localized: "add.duplicate.message", defaultValue: "A matching amount was recorded moments ago."))
        }
        .sheet(isPresented: $isPickingCategory) {
            CategoryPickerSheet(
                recent: model.recentCategories,
                all: model.categories,
                selectedID: model.selectedCategoryID
            ) { category in
                withAnimation(Motion.select) { model.selectCategory(category) }
            }
        }
        .onChange(of: model.didSave) { _, saved in
            guard saved else { return }
            router.dataDidChange()
            dismiss()
        }
    }
}

// MARK: - Type selector

private struct TypeSelector: View {
    @Binding var type: TransactionType
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TransactionType.allCases) { option in
                Button {
                    withAnimation(Motion.select) { type = option }
                } label: {
                    Text(option.localizedName)
                        .font(Typography.callout.weight(type == option ? .semibold : .regular))
                        .foregroundStyle(type == option ? Palette.ink : Palette.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                        .background {
                            if type == option {
                                RoundedRectangle(cornerRadius: Radius.control - 4, style: .continuous)
                                    .fill(Palette.surface)
                                    .matchedGeometryEffect(id: "typePill", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(type == option ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(Palette.surfaceSunken)
        .cardShape(Radius.control)
        .padding(.top, Spacing.xs)
    }
}

// MARK: - Amount

private struct AmountDisplay: View {
    let entry: AmountEntry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
            Text(MoneyFormatter.currencySymbol(for: entry.currency))
                .font(Typography.amountTitle)
                .foregroundStyle(Palette.inkTertiary)

            Text(entry.displayString())
                .font(Typography.amountDisplay())
                .monospacedDigit()
                .foregroundStyle(entry.isEmpty ? Palette.inkTertiary : Palette.ink)
                .contentTransition(.numericText(value: Double(entry.money.minorUnits)))
                .motion(Motion.number, value: entry.money.minorUnits, reduceMotion: reduceMotion)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.m)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Amount"))
        .accessibilityValue(MoneyFormatter.string(entry.money, fraction: .always))
    }
}

// MARK: - Transfer

private struct TransferPicker: View {
    @Bindable var model: AddTransactionViewModel

    var body: some View {
        AppCard(padding: Spacing.m) {
            VStack(spacing: Spacing.s) {
                accountRow(
                    label: String(localized: "add.from", defaultValue: "From"),
                    selection: $model.selectedAccountID
                )
                Divider().overlay(Palette.hairline)
                accountRow(
                    label: String(localized: "add.to", defaultValue: "To"),
                    selection: $model.destinationAccountID
                )
            }
        }
    }

    private func accountRow(label: String, selection: Binding<UUID?>) -> some View {
        HStack {
            Text(label)
                .font(Typography.callout)
                .foregroundStyle(Palette.inkSecondary)
            Spacer()
            Picker(label, selection: selection) {
                Text(String(localized: "add.choose", defaultValue: "Choose")).tag(UUID?.none)
                ForEach(model.accounts) { account in
                    Text(account.name).tag(UUID?.some(account.id))
                }
            }
            .labelsHidden()
            .tint(Palette.accent)
        }
    }
}

// MARK: - Details

private struct DetailsCard: View {
    @Bindable var model: AddTransactionViewModel
    @FocusState.Binding var focusedField: AddTransactionView.Field?

    var body: some View {
        AppCard(padding: Spacing.m) {
            VStack(spacing: Spacing.s) {
                HStack {
                    Label(String(localized: "add.account", defaultValue: "Account"), systemImage: "wallet.bifold")
                        .font(Typography.callout)
                        .foregroundStyle(Palette.inkSecondary)
                        .labelStyle(.titleAndIcon)
                    Spacer()
                    Picker(String(localized: "add.account", defaultValue: "Account"), selection: $model.selectedAccountID) {
                        ForEach(model.accounts) { account in
                            Text(account.name).tag(UUID?.some(account.id))
                        }
                    }
                    .labelsHidden()
                    .tint(Palette.accent)
                }

                Divider().overlay(Palette.hairline)

                DatePicker(
                    selection: $model.date,
                    in: ...Date.now.addingTimeInterval(60 * 60 * 24 * 365),
                    displayedComponents: [.date, .hourAndMinute]
                ) {
                    Label(String(localized: "add.when", defaultValue: "When"), systemImage: "calendar")
                        .font(Typography.callout)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .tint(Palette.accent)

                Divider().overlay(Palette.hairline)

                TextField(
                    String(localized: "add.merchant", defaultValue: "Merchant"),
                    text: $model.merchant
                )
                .font(Typography.body)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .merchant)
                .submitLabel(.next)

                if !model.merchantSuggestions.isEmpty, focusedField == .merchant {
                    ScrollView(.horizontal) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(model.merchantSuggestions, id: \.self) { name in
                                Button(name) { model.merchant = name }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                Divider().overlay(Palette.hairline)

                TextField(
                    String(localized: "add.note", defaultValue: "Note"),
                    text: $model.note,
                    axis: .vertical
                )
                .font(Typography.body)
                .lineLimit(1...3)
                .focused($focusedField, equals: .note)

                Divider().overlay(Palette.hairline)

                Toggle(isOn: $model.isRecurring.animation(Motion.layout)) {
                    Label(String(localized: "add.repeats", defaultValue: "Repeats"), systemImage: "arrow.clockwise")
                        .font(Typography.callout)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .tint(Palette.accent)

                if model.isRecurring {
                    Picker(String(localized: "add.frequency", defaultValue: "Frequency"), selection: $model.frequency) {
                        ForEach(RecurringFrequency.allCases) { frequency in
                            Text(frequency.localizedName).tag(frequency)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.accent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Keypad

private struct AmountKeypad: View {
    @Binding var entry: AmountEntry
    let onSave: () -> Void
    let canSave: Bool

    private let keys: [[KeypadKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.decimal, .digit(0), .delete],
    ]

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Spacing.s) {
                    ForEach(row) { key in
                        KeypadButton(key: key) { press(key) }
                    }
                }
            }

            Button(action: onSave) {
                Text("Save")
            }
            // Deliberately not `.disabled`: tapping it explains what's still needed.
            .buttonStyle(PrimaryButtonStyle(isEnabled: canSave))
            .padding(.top, Spacing.xxs)
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.xs)
        .background(Palette.canvas)
    }

    private func press(_ key: KeypadKey) {
        switch key {
        case .digit(let value): entry.append(digit: value)
        case .decimal: entry.appendDecimalSeparator()
        case .delete: entry.deleteBackward()
        }
    }
}

private enum KeypadKey: Identifiable, Hashable {
    case digit(Int)
    case decimal
    case delete

    var id: String {
        switch self {
        case .digit(let value): "d\(value)"
        case .decimal: "decimal"
        case .delete: "delete"
        }
    }
}

private struct KeypadButton: View {
    let key: KeypadKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch key {
                case .digit(let value):
                    Text(value.formatted())
                        .font(.system(size: 26, weight: .regular, design: .rounded))
                case .decimal:
                    Text(Locale.current.decimalSeparator ?? ".")
                        .font(.system(size: 26, weight: .regular, design: .rounded))
                case .delete:
                    Image(systemName: "delete.left")
                        .font(.system(size: 20, weight: .medium))
                }
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Palette.surface)
            .cardShape(Radius.control)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 0.5)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch key {
        case .digit(let value): value.formatted()
        case .decimal: String(localized: "keypad.decimal", defaultValue: "Decimal point")
        case .delete: String(localized: "keypad.delete", defaultValue: "Delete")
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    AddTransactionView()
        .environment(container)
        .environment(AppRouter())
        .modelContainer(container.modelContainer)
}

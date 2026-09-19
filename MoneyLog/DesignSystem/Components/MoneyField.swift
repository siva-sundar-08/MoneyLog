import SwiftUI

// A text field for typing an amount, used in the budget and goal editors.
//
// What the user types is text; this converts it into whole paise via Money, so a
// typed amount never passes through a Double on its way to the database.
struct MoneyField: View {
    let currency: CurrencyCode
    @Binding var minorUnits: Int64
    var placeholder: String = "0"

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Text(MoneyFormatter.currencySymbol(for: currency))
                .font(Typography.amountBody)
                .foregroundStyle(Palette.inkTertiary)

            TextField(placeholder, text: $text)
                .font(Typography.amountTitle)
                .monospacedDigit()
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    minorUnits = Self.parse(newValue, currency: currency)
                }
        }
        // The field is right-aligned and short; the whole row should still focus it.
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
        .onAppear {
            if minorUnits > 0, text.isEmpty {
                text = Money(minorUnits: minorUnits, currency: currency)
                    .decimalValue
                    .formatted(.number.grouping(.never).precision(.fractionLength(0...currency.minorUnitDigits)))
            }
        }
        .toolbar {
            if isFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "action.done", defaultValue: "Done")) { isFocused = false }
                }
            }
        }
    }

    static func parse(_ input: String, currency: CurrencyCode, locale: Locale = .current) -> Int64 {
        let separator = locale.decimalSeparator ?? "."
        let cleaned = input
            .replacingOccurrences(of: locale.groupingSeparator ?? ",", with: "")
            .replacingOccurrences(of: separator, with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard let decimal = Decimal(string: cleaned), let money = Money(decimal: decimal, currency: currency) else {
            return 0
        }
        return max(money.minorUnits, 0)
    }
}

// One labelled row in an editor sheet, so every editor looks the same.
struct EditorRow<Content: View>: View {
    let label: String
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(width: 20)
            }
            Text(label)
                .font(Typography.callout)
                .foregroundStyle(Palette.inkSecondary)
            Spacer(minLength: Spacing.s)
            content
        }
        .padding(.vertical, 2)
    }
}

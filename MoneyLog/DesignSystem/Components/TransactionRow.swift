import SwiftUI

// One line in a list of transactions: symbol, name, and amount.
struct TransactionRow: View {
    let transaction: TransactionRecord
    var showsDate = false

    var body: some View {
        HStack(spacing: Spacing.s) {
            CategoryGlyph(symbolName: glyphSymbol, tint: glyphTint, size: .medium)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayTitle)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.xs)

            AmountText(
                money: transaction.amount,
                size: .body,
                color: Palette.amountColor(for: transaction.type),
                showsPlusSign: transaction.type == .income
            )
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var glyphSymbol: String {
        if transaction.type == .transfer { return "arrow.left.arrow.right" }
        return transaction.category?.symbolName ?? "square.grid.2x2"
    }

    private var glyphTint: TintKey {
        if transaction.type == .transfer { return .slate }
        return transaction.category?.tint ?? .slate
    }

    private var subtitle: String {
        var parts: [String] = []
        if transaction.type == .transfer {
            let from = transaction.account?.name ?? ""
            let to = transaction.destinationAccount?.name ?? ""
            parts.append("\(from) → \(to)")
        } else if let category = transaction.category {
            parts.append(category.name)
        }
        parts.append(
            showsDate
            ? transaction.date.formatted(.dateTime.day().month(.abbreviated))
            : transaction.date.formatted(date: .omitted, time: .shortened)
        )
        return parts.joined(separator: " · ")
    }
}

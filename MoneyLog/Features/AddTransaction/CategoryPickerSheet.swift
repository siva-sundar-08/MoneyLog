import SwiftUI

// The category chooser that slides up from the bottom.
//
// It replaced a horizontal row of categories that scrolled sideways, which meant
// most of them were off-screen and you had to go hunting. A grid shows everything
// at once, and it closes the moment you pick one.
struct CategoryPickerSheet: View {
    let recent: [TransactionCategory]
    let all: [TransactionCategory]
    let selectedID: UUID?
    let onSelect: (TransactionCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 4)

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var matches: [TransactionCategory] {
        guard isSearching else { return all }
        return all.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                if matches.isEmpty {
                    EmptyState(
                        symbolName: "magnifyingglass",
                        title: String(localized: "picker.noMatch.title", defaultValue: "No category matches"),
                        message: String(localized: "picker.noMatch.message", defaultValue: "Try a different word, or add this category in Settings."),
                        actionTitle: String(localized: "action.clear", defaultValue: "Clear"),
                        action: { searchText = "" }
                    )
                    .padding(.horizontal, Spacing.xl)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.l) {
                            if !recent.isEmpty, !isSearching {
                                section(
                                    title: String(localized: "picker.recent", defaultValue: "Recent"),
                                    categories: recent
                                )
                            }

                            section(
                                title: isSearching
                                    ? String(localized: "picker.results", defaultValue: "Results")
                                    : String(localized: "picker.all", defaultValue: "All categories"),
                                categories: matches
                            )
                        }
                        .padding(.horizontal, Spacing.gutter)
                        .padding(.vertical, Spacing.m)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle(Text("Category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func section(title: String, categories: [TransactionCategory]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            MicroLabel(title)

            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.m) {
                ForEach(categories) { category in
                    CategoryTile(
                        category: category,
                        isSelected: selectedID == category.id
                    ) {
                        Haptics.play(.categorySelected)
                        onSelect(category)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CategoryTile: View {
    let category: TransactionCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                CategoryGlyph(
                    symbolName: category.symbolName,
                    tint: category.tint,
                    size: .large,
                    isSelected: isSelected
                )
                .scaleEffect(isSelected ? 1.06 : 1)

                Text(category.name)
                    .font(Typography.caption)
                    .foregroundStyle(isSelected ? Palette.ink : Palette.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// The row on the Add screen that opens the picker above.
struct CategoryField: View {
    let category: TransactionCategory?
    let isMissing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                CategoryGlyph(
                    symbolName: category?.symbolName ?? "square.grid.2x2",
                    tint: category?.tint ?? .slate,
                    size: .medium
                )

                VStack(alignment: .leading, spacing: 1) {
                    MicroLabel(String(localized: "add.category", defaultValue: "Category"))
                    Text(category?.name ?? String(localized: "add.chooseCategory", defaultValue: "Choose a category"))
                        .font(Typography.body)
                        .foregroundStyle(category == nil ? Palette.inkTertiary : Palette.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.xs)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface)
            .cardShape(Radius.control)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(isMissing ? Palette.caution : Palette.hairline, lineWidth: isMissing ? 1 : 0.5)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text("Category"))
        .accessibilityValue(category?.name ?? String(localized: "add.chooseCategory", defaultValue: "Choose a category"))
    }
}

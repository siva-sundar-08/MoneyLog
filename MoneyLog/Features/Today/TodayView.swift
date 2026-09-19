import SwiftUI

// The home screen: balance, this month's totals, accounts, and recent transactions.
//
// The view itself only arranges things. All the adding-up happens in
// TodayViewModel, which is why this file reads like a description of the layout
// rather than a pile of calculations.
struct TodayView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: TodayViewModel?

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.isPresentingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .accessibilityLabel(Text("Settings"))
                }
            }
            .toolbarBackground(Palette.canvas, for: .navigationBar)
        }
        .overlay(alignment: .bottomTrailing) {
            QuickAddButton { router.isPresentingAdd = true }
                .padding(.trailing, Spacing.gutter)
                // Clears the floating tab bar so neither target steals the other's taps.
                .padding(.bottom, Spacing.xxl)
        }
        .task {
            if model == nil { model = TodayViewModel(container: container) }
            model?.load()
        }
        .onChange(of: router.dataVersion) { _, _ in model?.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model?.load() }
        }
    }

    @ViewBuilder
    private func content(_ model: TodayViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                greeting
                    .reveal(0)

                BalanceCard(snapshot: model.snapshot, insight: model.insight)
                    .reveal(1)

                MonthPulseCard(snapshot: model.snapshot, monthName: model.monthName)
                    .reveal(2)

                if let budget = model.snapshot.budget {
                    BudgetPaceCard(budget: budget, currency: model.snapshot.currency)
                        .reveal(3)
                }

                if !model.snapshot.accounts.isEmpty {
                    AccountsStrip(accounts: model.snapshot.accounts)
                        .reveal(4)
                }

                if let goal = model.snapshot.goal {
                    GoalCard(goal: goal)
                        .reveal(5)
                }

                RecentTransactionsCard(
                    transactions: model.snapshot.recent,
                    onSeeAll: { router.selectedTab = .activity },
                    onAdd: { router.isPresentingAdd = true }
                )
                .reveal(6)

                if let errorMessage = model.errorMessage {
                    InlineErrorBanner(message: errorMessage)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.xxl + Spacing.xl)
        }
        .scrollIndicators(.hidden)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            MicroLabel(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            Text(greetingText)
                .font(Typography.displaySerif)
                .foregroundStyle(Palette.ink)
        }
        .padding(.top, Spacing.xs)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return String(localized: "greeting.morning", defaultValue: "Good morning")
        case 12..<17: return String(localized: "greeting.afternoon", defaultValue: "Good afternoon")
        case 17..<22: return String(localized: "greeting.evening", defaultValue: "Good evening")
        default: return String(localized: "greeting.night", defaultValue: "Still up?")
        }
    }
}

// The round + button, bottom right.
//
// It sits low on purpose: that's where your thumb already is when holding a phone
// one-handed, and adding an expense is the thing people do most.
private struct QuickAddButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 58, height: 58)
                .background(Palette.accent)
                .clipShape(.circle)
                .shadow(color: .black.opacity(Elevation.shadowOpacity(for: scheme, floating: true)), radius: 14, y: 6)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text("Add transaction"))
    }
}

struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
                .font(Typography.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Palette.over)
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.over.opacity(0.10))
        .cardShape(Radius.control)
    }
}

#Preview {
    let container = AppContainer.preview()
    RootTabView()
        .environment(container)
        .modelContainer(container.modelContainer)
}

import SwiftUI

// The tab bar and the four screens hanging off it.
//
// This is the skeleton of the app: Today, Activity, Insights, Plan. It also owns
// the two sheets that can appear from anywhere — Add transaction and Settings —
// because a sheet has to be presented by something that's always on screen.
struct RootTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("Today", systemImage: "house", value: AppTab.today) {
                TodayView()
            }
            Tab("Activity", systemImage: "list.bullet", value: AppTab.activity) {
                ActivityView()
            }
            Tab("Insights", systemImage: "chart.bar", value: AppTab.insights) {
                InsightsView()
            }
            Tab("Plan", systemImage: "target", value: AppTab.plan) {
                PlanView()
            }
        }
        .tint(Palette.accent)
        .environment(router)
        .sheet(isPresented: $router.isPresentingAdd) {
            AddTransactionView()
                .environment(container)
                .environment(router)
        }
        .sheet(isPresented: $router.isPresentingSettings) {
            SettingsView()
                .environment(container)
                .environment(router)
        }
    }
}

struct ComingSoonScreen: View {
    let title: String
    let symbolName: String
    let message: String

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()
                EmptyState(
                    symbolName: symbolName,
                    title: title,
                    message: message
                )
                .padding(.horizontal, Spacing.xl)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
        }
    }
}


import SwiftUI
import SwiftData

struct RootView: View {
    let bootstrap: AppBootstrap
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PreferenceKey.appearance) private var appearanceRaw = AppearanceSetting.system.rawValue

    var body: some View {
        content
            .preferredColorScheme(AppearanceSetting(rawValue: appearanceRaw)?.colorScheme)
            .task { bootstrap.start() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { bootstrap.sceneDidBecomeActive() }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch bootstrap.state {
        case .launching:
            ProgressView()
                .accessibilityLabel(Text("Opening your data"))
        case .ready(let container):
            RootTabView()
                .environment(container)
                .modelContainer(container.modelContainer)
        case .failed(let error):
            StoreFailureView(error: error, retry: { bootstrap.start() })
        }
    }
}

private struct StoreFailureView: View {
    let error: AppError
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(error.localizedDescription, systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(error.recoverySuggestion ?? "")
        } actions: {
            Button(action: retry) {
                Text("Try again")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

import SwiftUI
import SwiftData

// The starting point. @main tells iOS "run this when the app opens".
//
// Deliberately tiny: it creates the bootstrap object and shows RootView, which
// decides what to draw while the database opens. Everything else lives elsewhere.
@main
struct MoneyLogApp: App {
    @State private var bootstrap = AppBootstrap()

    var body: some Scene {
        WindowGroup {
            RootView(bootstrap: bootstrap)
        }
    }
}

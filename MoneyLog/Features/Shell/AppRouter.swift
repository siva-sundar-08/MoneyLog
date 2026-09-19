import Foundation
import Observation

enum AppTab: Hashable {
    case today, activity, insights, plan
}

// Keeps track of where the user is: which tab is showing, whether a sheet is open.
//
// Having one object own this means any part of the app can say "open the add
// sheet" without the screens having to talk to each other. It's also what a Siri
// shortcut or a notification tap would use to land on the right screen.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    var isPresentingAdd = false
    var isPresentingSettings = false
    // A counter that goes up every time something is saved or deleted.
    //
    // Screens watch it and reload when it changes. It's a blunt approach — every
    // screen reloads even if the change didn't affect it — but with a local
    // database that takes a millisecond, and it's impossible to get wrong.
    private(set) var dataVersion = 0

    func dataDidChange() { dataVersion += 1 }
}

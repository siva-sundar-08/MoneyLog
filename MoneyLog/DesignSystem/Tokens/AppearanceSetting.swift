import SwiftUI

// The Light / Dark / System choice in Settings.
// "System" means nil, which is SwiftUI's way of saying "follow the phone".
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var localizedName: String {
        switch self {
        case .system: String(localized: "appearance.system", defaultValue: "System")
        case .light: String(localized: "appearance.light", defaultValue: "Light")
        case .dark: String(localized: "appearance.dark", defaultValue: "Dark")
        }
    }
}

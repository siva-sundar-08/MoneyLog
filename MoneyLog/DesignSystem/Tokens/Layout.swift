import SwiftUI

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    // The margin down both sides of every screen. Keeping it identical is half of what makes an app feel tidy.
    static let gutter: CGFloat = 20
}

enum Radius {
    static let card: CGFloat = 22
    static let control: CGFloat = 14
    static let glyph: CGFloat = 13
    static let bar: CGFloat = 6
}

enum Elevation {
    // How much shadow a card casts. Light mode gets a soft one; dark mode gets none,
    // because a shadow on a near-black background is just mud. Depth there comes
    // from the card being slightly lighter than the page instead.
    static func shadowOpacity(for scheme: ColorScheme, floating: Bool = false) -> Double {
        guard scheme == .light else { return 0 }
        return floating ? 0.16 : 0.05
    }
}

extension View {
    func cardShape(_ radius: CGFloat = Radius.card) -> some View {
        clipShape(.rect(cornerRadius: radius, style: .continuous))
    }
}

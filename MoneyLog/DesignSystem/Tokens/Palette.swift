import SwiftUI

// Every colour in the app, in one file.
//
// The look is called "Ledger and Light": a warm paper background, near-black ink
// for text, and a single teal accent. Change a value here and it changes
// everywhere — no view ever writes its own colour.
//
// One decision worth knowing: expenses are ink, not red. Spending money is
// normal, and an app that shouts at you for buying lunch gets deleted. Red is
// saved for the one case that deserves it — going over a budget.
//
// Each colour gives iOS two versions, light and dark, and the system picks.
enum Palette {
    // MARK: Surfaces
    static let canvas = dynamic(light: 0xF5F3EE, dark: 0x0D0E0D)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x171917)
    static let surfaceSunken = dynamic(light: 0xECE9E2, dark: 0x111211)
    static let surfaceRaised = dynamic(light: 0xFFFFFF, dark: 0x1E211E)

    // MARK: Ink
    static let ink = dynamic(light: 0x141514, dark: 0xF1EFEA)
    static let inkSecondary = dynamic(light: 0x5B5F5A, dark: 0xA3A8A0)
    static let inkTertiary = dynamic(light: 0x8C918A, dark: 0x70756E)
    static let hairline = dynamic(light: 0x141514, dark: 0xF1EFEA, lightAlpha: 0.08, darkAlpha: 0.10)

    // MARK: Meaning
    static let accent = dynamic(light: 0x1E5A5A, dark: 0x5FB3AC)
    static let accentSoft = dynamic(light: 0x1E5A5A, dark: 0x5FB3AC, lightAlpha: 0.10, darkAlpha: 0.18)
    static let income = dynamic(light: 0x3C7A4E, dark: 0x7CC293)
    static let caution = dynamic(light: 0xB7791F, dark: 0xE0A84A)
    static let over = dynamic(light: 0xB4442F, dark: 0xE27A64)

    // The colours behind category symbols. All muted and of similar weight, so no
    // single category shouts louder than the rest.
    static func tint(_ key: TintKey) -> Color {
        switch key {
        case .teal: dynamic(light: 0x1E5A5A, dark: 0x5FB3AC)
        case .sage: dynamic(light: 0x3C7A4E, dark: 0x7CC293)
        case .sand: dynamic(light: 0x8A6E3F, dark: 0xD0AE74)
        case .terracotta: dynamic(light: 0xA65038, dark: 0xE08C71)
        case .plum: dynamic(light: 0x6B4570, dark: 0xBC93C2)
        case .ochre: dynamic(light: 0x9A7B10, dark: 0xD6BA55)
        case .slate: dynamic(light: 0x4A5763, dark: 0x9BAAB8)
        case .rose: dynamic(light: 0xA14761, dark: 0xDD90A6)
        case .moss: dynamic(light: 0x55702F, dark: 0xA8C173)
        case .indigo: dynamic(light: 0x3A4C86, dark: 0x8C9FDA)
        }
    }

    // A faint version of a tint, for sitting behind a symbol.
    static func tintWash(_ key: TintKey) -> Color {
        tint(key).opacity(0.12)
    }

    static func amountColor(for type: TransactionType) -> Color {
        switch type {
        case .income: income
        case .expense: ink
        case .transfer: inkSecondary
        }
    }

    // MARK: Builder

    static func dynamic(
        light: UInt32,
        dark: UInt32,
        lightAlpha: Double = 1,
        darkAlpha: Double = 1
    ) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: Double) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}

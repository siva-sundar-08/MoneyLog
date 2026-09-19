import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .background(isEnabled ? Palette.accent : Palette.inkTertiary)
            .cardShape(Radius.control)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.callout.weight(.medium))
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(Palette.accentSoft)
            .clipShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

// For things that are tappable but shouldn't look like buttons — cards and chips.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

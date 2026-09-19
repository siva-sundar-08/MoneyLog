import SwiftUI

// What a screen shows when there's nothing to show yet.
//
// An empty screen is a chance to tell someone what to do next, so every one of
// these names what's missing and offers the button that fixes it. "No data"
// on its own helps nobody.
struct EmptyState: View {
    let symbolName: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: symbolName)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.accent)
                .padding(Spacing.m)
                .background(Palette.accentSoft)
                .clipShape(.circle)

            Text(title)
                .font(Typography.insightSerif)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Typography.callout)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, Spacing.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.l)
    }
}

import SwiftUI

// The white card that most content sits on.
//
// There's one card component in the whole app, not several near-identical ones.
// That's how every screen ends up with the same corners, the same hairline edge
// and the same shadow without anyone having to remember the numbers.
struct AppCard<Content: View>: View {
    var padding: CGFloat = Spacing.l
    var radius: CGFloat = Radius.card
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface)
            .cardShape(radius)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(Elevation.shadowOpacity(for: scheme)), radius: 16, x: 0, y: 8)
    }
}

// The page behind everything: warm off-white with a faint grain.
//
// The grain is about 3% opacity — you won't consciously see it, but it stops the
// background from looking like flat grey and nudges it towards paper. It's drawn
// in code rather than shipped as an image, so it costs nothing to download and
// works at any screen size.
struct CanvasBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Palette.canvas
            .overlay {
                if !reduceTransparency {
                    GrainTexture().opacity(0.035)
                }
            }
            .ignoresSafeArea()
    }
}

private struct GrainTexture: View {
    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 42)
            let dots = Int((size.width * size.height) / 900)
            for _ in 0..<dots {
                let x = Double.random(in: 0...size.width, using: &generator)
                let y = Double.random(in: 0...size.height, using: &generator)
                let side = Double.random(in: 0.5...1.4, using: &generator)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: side, height: side)),
                    with: .color(Palette.ink)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// Our own random number generator, seeded with a fixed number.
//
// Swift's normal random would scatter the grain differently on every redraw, and
// the background would shimmer as you scroll. A fixed seed means the same speckles
// land in the same places every time.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 6_364_136_223_846_793_005 &+ 1 }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

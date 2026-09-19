import SwiftUI

// All the animation timings, named by what they're for.
//
// Views pick from this list instead of inventing their own numbers. That's what
// makes the whole app feel like it moves the same way, rather than each screen
// having its own personality.
enum Motion {
    // Quick and flat — for taps, where any delay feels like lag.
    static let tap = Animation.snappy(duration: 0.18, extraBounce: 0)
    // A little bounce, for something sliding into a new place.
    static let select = Animation.spring(response: 0.32, dampingFraction: 0.78)
    // Smooth, for things appearing and disappearing from a list.
    static let layout = Animation.smooth(duration: 0.35)
    // The gentle fade-in when a screen first draws.
    static let reveal = Animation.easeOut(duration: 0.5)
    // Slower and springy, for a progress bar or ring filling up.
    static let progress = Animation.spring(response: 0.8, dampingFraction: 0.9)
    // For numbers rolling from one value to another.
    static let number = Animation.smooth(duration: 0.4)

    static let revealStagger: Double = 0.035
    static let maxStaggeredItems = 6
}

// Makes cards fade up as a screen appears, each one a fraction after the last.
//
// If the user has Reduce Motion turned on in iOS Settings — which people with
// motion sensitivity do — the sliding is dropped and only the fade remains.
struct RevealModifier: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : 14)
            .onAppear {
                guard !hasAppeared else { return }
                let delay = Double(min(index, Motion.maxStaggeredItems)) * Motion.revealStagger
                withAnimation(Motion.reveal.delay(delay)) { hasAppeared = true }
            }
    }
}

extension View {
    func reveal(_ index: Int) -> some View {
        modifier(RevealModifier(index: index))
    }

    // Animate, unless the user asked iOS for less motion.
    @ViewBuilder
    func motion<V: Equatable>(_ animation: Animation, value: V, reduceMotion: Bool) -> some View {
        if reduceMotion {
            self
        } else {
            self.animation(animation, value: value)
        }
    }
}

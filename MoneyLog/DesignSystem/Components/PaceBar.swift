import SwiftUI

// A budget bar with a small tick showing where you *should* be today.
//
// A bare percentage ("62% used") doesn't answer the real question, which is
// whether that's fine. Spending 62% on the 20th of the month is fine; on the 5th
// it isn't. The tick makes that obvious without any maths.
struct PaceBar: View {
    let progress: Double
    let expectedProgress: Double
    let color: Color
    var height: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let filled = width * min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceSunken)

                Capsule()
                    .fill(color)
                    .frame(width: max(filled, progress > 0 ? height : 0))
                    .motion(Motion.progress, value: progress, reduceMotion: reduceMotion)

                if expectedProgress > 0.02, expectedProgress < 0.98 {
                    Capsule()
                        .fill(Palette.ink.opacity(0.35))
                        .frame(width: 1.5, height: height + 6)
                        .offset(x: width * expectedProgress)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

import SwiftUI

// The ring itself: a grey track with a coloured arc drawn over it.
// The circular progress ring used for budgets and savings goals.
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    var color: Color = Palette.accent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.surfaceSunken, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .motion(Motion.progress, value: clamped, reduceMotion: reduceMotion)
        }
        .accessibilityHidden(true)
    }
}

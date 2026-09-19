import UIKit

// The little taps you feel through the phone.
//
// There are exactly six here, and that's the point. Buzz on everything and people
// turn haptics off; save them for moments that matter and each one still means
// something.
@MainActor
enum Haptics {
    enum Event {
        case saved
        case categorySelected
        case deleted
        case blocked
        case budgetThreshold
        case goalCompleted
    }

    static func play(_ event: Event) {
        switch event {
        case .saved, .goalCompleted:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .categorySelected:
            UISelectionFeedbackGenerator().selectionChanged()
        case .deleted:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .blocked, .budgetThreshold:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}

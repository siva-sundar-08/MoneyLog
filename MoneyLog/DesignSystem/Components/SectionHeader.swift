import SwiftUI

// A small heading above a section, with room for a button on the right.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            MicroLabel(title)
            Spacer(minLength: Spacing.s)
            trailing
        }
        .padding(.horizontal, Spacing.xxs)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

import SwiftUI

// The little rounded square with a symbol in it, used for categories and accounts.
//
// Three fixed sizes and one symbol weight. Fixed choices like these are why the
// app looks consistent — there's no opportunity to pick a slightly different size
// on a slightly different screen.
struct CategoryGlyph: View {
    enum Size {
        case small, medium, large

        var side: CGFloat {
            switch self {
            case .small: 32
            case .medium: 40
            case .large: 56
            }
        }

        var symbol: CGFloat {
            switch self {
            case .small: 14
            case .medium: 17
            case .large: 23
            }
        }
    }

    let symbolName: String
    let tint: TintKey
    var size: Size = .medium
    var isSelected = false

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size.symbol, weight: .medium))
            .foregroundStyle(Palette.tint(tint))
            .frame(width: size.side, height: size.side)
            .background(Palette.tintWash(tint))
            .cardShape(Radius.glyph)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.glyph, style: .continuous)
                    .strokeBorder(Palette.tint(tint), lineWidth: isSelected ? 1.5 : 0)
            }
            .accessibilityHidden(true)
    }
}

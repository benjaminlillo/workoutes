import SwiftUI

/// Independently tinted vector masks keep the anatomy neutral and the muscle in the tag's color.
struct MuscleIconView: View {
    let icon: MuscleIcon
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Image(icon.baseAsset)
                .resizable()
                .scaledToFit()
                .foregroundStyle(colorScheme == .dark ? Color(white: 0.36) : Color(white: 0.78))
            Image(icon.highlightAsset)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
        }
        .accessibilityLabel(icon.name)
    }
}

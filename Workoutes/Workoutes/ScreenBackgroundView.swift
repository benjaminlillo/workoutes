import SwiftUI

struct ScreenBackgroundView: View {
    let background: ExerciseBackgroundStore

    var body: some View {
        Group {
            if !background.gradientColors.isEmpty {
                SoftBackgroundGradient(colors: background.gradientColors)
            } else if let image = background.image {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            } else {
                Color(uiColor: .systemGroupedBackground)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SoftBackgroundGradient: View {
    let colors: [String]

    var body: some View {
        LinearGradient(colors: colors.map { Color(hex: $0) } + [.white],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(.white.opacity(0.72))
    }
}

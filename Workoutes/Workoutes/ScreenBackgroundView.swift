import SwiftUI

struct ScreenBackgroundView: View {
    let background: ExerciseBackgroundStore
    var tagColors: [String] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if background.usesAutomaticGradient {
                ZStack {
                    if tagColors.isEmpty {
                        DefaultScreenBackground().transition(.opacity)
                    } else {
                        SoftBackgroundGradient(colors: tagColors).transition(.opacity)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: tagColors)
            } else if background.usesDefaultGradient {
                DefaultScreenBackground()
            } else if !background.gradientColors.isEmpty {
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
                DefaultScreenBackground()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SoftBackgroundGradient: View {
    let colors: [String]

    var body: some View {
        AtmosphericBackgroundGradient(colors: colors)
    }
}

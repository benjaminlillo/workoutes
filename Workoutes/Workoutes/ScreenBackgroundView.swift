import SwiftUI

struct ScreenBackgroundView: View {
    let background: ExerciseBackgroundStore
    var tagColors: [String] = []

    var body: some View {
        Group {
            if background.usesAutomaticGradient {
                SoftBackgroundGradient(colors: ExerciseBackgroundStore.automaticColors(from: tagColors))
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
                Color(uiColor: .systemGroupedBackground)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SoftBackgroundGradient: View {
    @Environment(\.colorScheme) private var colorScheme
    let colors: [String]

    var body: some View {
        GeometryReader { geometry in
            let rows = max(1, (colors.count + 1) / 2)
            let radius = max(geometry.size.width * 0.9,
                             geometry.size.height / Double(rows) * 0.85)

            ZStack {
                colorScheme == .dark
                    ? Color(red: 0.035, green: 0.04, blue: 0.055)
                    : Color.white
                ForEach(colors.indices, id: \.self) { index in
                    let x = colors.count == 1 ? 0.5 : (index.isMultiple(of: 2) ? 0.2 : 0.8)
                    let y = rows == 1 ? 0.5 : 0.15 + 0.7 * Double(index / 2) / Double(rows - 1)

                    Circle()
                        .fill(RadialGradient(
                            stops: [
                                .init(color: Color(hex: colors[index]).opacity(colorScheme == .dark ? 0.5 : 0.4), location: 0),
                                .init(color: Color(hex: colors[index]).opacity(colorScheme == .dark ? 0.25 : 0.2), location: 0.45),
                                .init(color: Color(hex: colors[index]).opacity(0), location: 1)
                            ],
                            center: .center, startRadius: 0, endRadius: radius
                        ))
                        .frame(width: radius * 2, height: radius * 2)
                        .blur(radius: min(geometry.size.width, geometry.size.height) * 0.08)
                        .position(x: geometry.size.width * x, y: geometry.size.height * y)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

import SwiftUI

/// Static color fields over a vertical gradient, finished with a reusable PNG grain overlay.
struct AtmosphericBackgroundGradient: View {
    let colors: [String]
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    private var palette: [Color] {
        let resolved = colors.isEmpty ? ["6C3DD1", "B784E8", "F3DDF2"] : colors
        return (0..<3).map { Color(hex: resolved[min($0, resolved.count - 1)]) }
    }

    var body: some View {
        GeometryReader { geometry in
            let palette = palette
            let radius = max(geometry.size.width * 1.05, geometry.size.height * 0.65)

            ZStack {
                isDark ? Color(red: 0.035, green: 0.04, blue: 0.055) : Color.white

                LinearGradient(
                    colors: [
                        palette[2].opacity(isDark ? 0.4 : 0.8),
                        palette[1].opacity(isDark ? 0.26 : 0.48),
                        palette[0].opacity(isDark ? 0.48 : 0.64)
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                colorField(palette[1], center: UnitPoint(x: -0.12, y: 0.12), radius: radius,
                           opacity: isDark ? 0.36 : 0.48)
                colorField(palette[2], center: UnitPoint(x: 1.05, y: 0.25), radius: radius * 0.85,
                           opacity: isDark ? 0.22 : 0.5)
                colorField(palette[0], center: UnitPoint(x: -0.08, y: 1.02), radius: radius * 0.9,
                           opacity: isDark ? 0.5 : 0.48)
                colorField(palette[1], center: UnitPoint(x: 1.1, y: 0.8), radius: radius * 0.75,
                           opacity: isDark ? 0.2 : 0.38)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay { BackgroundFilmGrain() }
            .compositingGroup()
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func colorField(_ color: Color, center: UnitPoint, radius: CGFloat,
                            opacity: Double) -> some View {
        RadialGradient(
            stops: [
                .init(color: color.opacity(opacity), location: 0),
                .init(color: color.opacity(opacity * 0.65), location: 0.35),
                .init(color: color.opacity(opacity * 0.15), location: 0.75),
                .init(color: color.opacity(0), location: 1)
            ],
            center: center, startRadius: 0, endRadius: radius
        )
    }
}

private struct BackgroundFilmGrain: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(ImagePaint(image: Image("BackgroundFilmGrain").interpolation(.none),
                             scale: 1 / max(1, displayScale)))
            .blendMode(.overlay)
            .opacity(0.4)
    }
}

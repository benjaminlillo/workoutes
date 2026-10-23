import SwiftUI

/// Broad color fields over a vertical gradient, finished with fine photographic grain.
struct AtmosphericBackgroundGradient: View {
    let colors: [String]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var drifting = false

    private var isDark: Bool { colorScheme == .dark }
    private var animates: Bool { !reduceMotion && scenePhase == .active }

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

                colorField(palette[1], center: UnitPoint(x: -0.12, y: 0.12), radius: radius, size: geometry.size,
                           opacity: isDark ? 0.36 : 0.48, duration: 24,
                           offset: CGSize(width: geometry.size.width * 0.08, height: geometry.size.height * 0.035))
                colorField(palette[2], center: UnitPoint(x: 1.05, y: 0.25), radius: radius * 0.85, size: geometry.size,
                           opacity: isDark ? 0.22 : 0.5, duration: 28,
                           offset: CGSize(width: -geometry.size.width * 0.06, height: geometry.size.height * 0.025))
                colorField(palette[0], center: UnitPoint(x: -0.08, y: 1.02), radius: radius * 0.9, size: geometry.size,
                           opacity: isDark ? 0.5 : 0.48, duration: 26,
                           offset: CGSize(width: geometry.size.width * 0.05, height: -geometry.size.height * 0.04))
                colorField(palette[1], center: UnitPoint(x: 1.1, y: 0.8), radius: radius * 0.75, size: geometry.size,
                           opacity: isDark ? 0.2 : 0.38, duration: 22,
                           offset: CGSize(width: -geometry.size.width * 0.07, height: -geometry.size.height * 0.025))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay { BackgroundFilmGrain() }
            .compositingGroup()
            .clipped()
        }
        .onChange(of: animates, initial: true) { drifting = animates }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func colorField(_ color: Color, center: UnitPoint, radius: CGFloat, size: CGSize,
                            opacity: Double, duration: Double, offset: CGSize) -> some View {
        // Draw beyond the viewport so drifting never exposes a gradient layer's rectangular edge.
        let bleed = max(1, max(size.width, size.height) * 0.2)
        let expanded = CGSize(width: size.width + bleed * 2, height: size.height + bleed * 2)
        let expandedCenter = UnitPoint(x: (center.x * size.width + bleed) / expanded.width,
                                       y: (center.y * size.height + bleed) / expanded.height)
        return RadialGradient(
            stops: [
                .init(color: color.opacity(opacity), location: 0),
                .init(color: color.opacity(opacity * 0.65), location: 0.35),
                .init(color: color.opacity(opacity * 0.15), location: 0.75),
                .init(color: color.opacity(0), location: 1)
            ],
            center: expandedCenter, startRadius: 0, endRadius: radius
        )
        .frame(width: expanded.width, height: expanded.height)
        .scaleEffect(drifting ? 1.07 : 1, anchor: expandedCenter)
        .offset(x: drifting ? offset.width : 0, y: drifting ? offset.height : 0)
        .frame(width: size.width, height: size.height)
        .animation(animates ? .easeInOut(duration: duration).repeatForever(autoreverses: true) : nil,
                   value: drifting)
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

import SwiftUI

/// Each tag keeps its native text on the rim, with enough space for its neighboring inscriptions.
struct PlateInscription: View {
    let text: String
    let angle: Double
    let arc: Double
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var fontSize = 14.0

    var body: some View {
        Rectangle()
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { content in
                content.foregroundStyle(color)
            }
            .mask { lettering }
            .shadow(color: .white.opacity(colorScheme == .dark ? 0.08 : 0.65), radius: 0, x: 0, y: 0.5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var lettering: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2 - 14
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let availableLength = radius * arc
            let font = Font.system(size: min(fontSize, 18), weight: .heavy, design: .rounded)
            var letters = Array(text.uppercased())
            let measure: (Character) -> (GraphicsContext.ResolvedText, CGFloat) = { character in
                let glyph = context.resolve(Text(String(character)).font(font).foregroundStyle(.white))
                return (glyph, glyph.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)).width)
            }
            var glyphs = letters.map(measure)
            let tracking: CGFloat = 1.2
            func length() -> CGFloat {
                glyphs.reduce(0) { $0 + $1.1 } + tracking * CGFloat(max(0, glyphs.count - 1))
            }
            // Keep long names readable; VoiceOver and the center menu retain the full name.
            let scale = max(0.75, min(1, availableLength / max(1, length())))
            if length() * scale > availableLength {
                while !letters.isEmpty && length() * scale > availableLength {
                    letters.removeLast()
                    glyphs = (letters + ["…"]).map(measure)
                }
            }
            var distance = -length() * scale / 2
            for (glyph, width) in glyphs {
                let glyphAngle = angle + (distance + width * scale / 2) / radius
                var letterContext = context
                letterContext.translateBy(x: center.x + cos(glyphAngle) * radius,
                                          y: center.y + sin(glyphAngle) * radius)
                letterContext.rotate(by: .radians(glyphAngle + .pi / 2))
                letterContext.scaleBy(x: scale, y: scale)
                letterContext.draw(glyph, at: .zero, anchor: .center)
                distance += (width + tracking) * scale
            }
        }
    }
}

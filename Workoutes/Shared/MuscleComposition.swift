import SwiftUI
import UIKit

/// The panels share the source drawing's coordinates at the waist and shoulders.
enum MusclePanel: String, CaseIterable {
    case upperFront, lowerFront, upperBack, lowerBack

    var isFront: Bool { self == .upperFront || self == .lowerFront }

    var bounds: CGRect {
        switch self {
        case .upperFront, .upperBack: CGRect(x: 0, y: 0, width: 310, height: 365)
        case .lowerFront: CGRect(x: 88, y: 282, width: 140, height: 338)
        case .lowerBack: CGRect(x: 88, y: 269, width: 140, height: 351)
        }
    }

    func asset(_ region: String) -> String { "anatomy-\(rawValue)-\(region)" }
}

extension MuscleIcon {
    var panels: [MusclePanel] {
        switch self {
        case .fullBody: MusclePanel.allCases
        case .upperBody, .arms, .shoulders, .forearms, .trapezius: [.upperFront, .upperBack]
        case .lowerBody, .calves, .adductors: [.lowerFront, .lowerBack]
        case .quadriceps, .tibialis: [.lowerFront]
        case .glutes, .hamstrings, .abductors: [.lowerBack]
        case .back, .triceps, .upperBack, .lowerBack, .posteriorDeltoid, .tricepsLongHead,
             .tricepsLateralHead, .tricepsMedialHead, .forearmExtensors, .lats:
            [.upperBack]
        case .core, .chest, .biceps, .abdominals, .obliques, .neck,
             .upperChest, .middleChest, .lowerChest, .anteriorDeltoid, .lateralDeltoid,
             .bicepsLongHead, .bicepsShortHead, .forearmFlexors, .brachioradialis,
             .transverseAbdominis, .externalObliques, .internalObliques:
            [.upperFront]
        }
    }
}

struct MuscleComposition {
    struct Highlight: Hashable {
        let icon: MuscleIcon
        let colorHex: String
    }

    let highlights: [Highlight]
    let dotColors: [String]
    private let panels: Set<MusclePanel>
    let cacheKey: String

    init(highlights: [Highlight], dotColors: [String] = []) {
        // Draw broad regions first so their smaller subdivisions keep their own color.
        self.highlights = Set(highlights).sorted {
            if $0.icon == $1.icon { return $0.colorHex < $1.colorHex }
            return Self.iconOrder[$0.icon, default: 0] < Self.iconOrder[$1.icon, default: 0]
        }
        self.dotColors = Set(dotColors).sorted()
        panels = Set(self.highlights.flatMap { $0.icon.panels })
        cacheKey = self.highlights.map { "\($0.icon.rawValue):\($0.colorHex)" }.joined(separator: ",")
            + "|" + self.dotColors.joined(separator: ",")
    }

    private static let iconOrder = Dictionary(uniqueKeysWithValues: MuscleIcon.allCases.enumerated().map {
        ($0.element, $0.offset)
    })

    private func placements(in rect: CGRect) -> [(MusclePanel, CGRect)] {
        let selected = panels
        let faces = [true, false].map { isFront in
            MusclePanel.allCases.filter { selected.contains($0) && $0.isFront == isFront }
        }.filter { !$0.isEmpty }
        guard !faces.isEmpty else { return [] }
        let spacing: CGFloat = 2
        let faceWidth = (rect.width - spacing * CGFloat(faces.count - 1)) / CGFloat(faces.count)
        return faces.enumerated().flatMap { index, panels in
            let source = panels.reduce(CGRect.null) { $0.union($1.bounds) }
            let scale = min(faceWidth / source.width, rect.height / source.height)
            let left = rect.minX + CGFloat(index) * (faceWidth + spacing) + (faceWidth - source.width * scale) / 2
            let top = rect.midY - source.height * scale / 2
            return panels.map { panel in
                let bounds = panel.bounds
                return (panel, CGRect(x: left + (bounds.minX - source.minX) * scale,
                                      y: top + (bounds.minY - source.minY) * scale,
                                      width: bounds.width * scale, height: bounds.height * scale))
            }
        }
    }

    func draw(in bounds: CGRect, context: CGContext, neutral: UIColor?, highlightsOnly: Bool,
              silhouetteOnly: Bool) {
        let dotHeight: CGFloat = dotColors.isEmpty ? 0 : 8
        let anatomy = bounds.insetBy(dx: 1, dy: 1)
        let panelBounds = CGRect(x: anatomy.minX, y: anatomy.minY, width: anatomy.width,
                                 height: anatomy.height - dotHeight)
        let placedPanels = placements(in: panelBounds)
        if let neutral {
            for (panel, rect) in placedPanels {
                UIImage(named: panel.asset("base"))?
                    .withTintColor(neutral, renderingMode: .alwaysOriginal).draw(in: rect)
            }
        }
        guard !silhouetteOnly else { return }
        for highlight in highlights {
            let tint = highlightsOnly ? UIColor.white : UIColor(Color(hex: highlight.colorHex))
            for (panel, rect) in placedPanels where highlight.icon.panels.contains(panel) {
                UIImage(named: panel.asset(highlight.icon.rawValue))?
                    .withTintColor(tint, renderingMode: .alwaysOriginal).draw(in: rect)
            }
        }
        guard !dotColors.isEmpty else { return }
        let step = min(8, anatomy.width / CGFloat(dotColors.count))
        let diameter = min(5, step * 0.75)
        let firstX = bounds.midX - step * CGFloat(dotColors.count - 1) / 2
        let centerY = highlights.isEmpty ? bounds.midY : anatomy.maxY - dotHeight / 2
        for (index, color) in dotColors.enumerated() {
            context.setFillColor(UIColor(Color(hex: color)).cgColor)
            context.fillEllipse(in: CGRect(x: firstX + CGFloat(index) * step - diameter / 2,
                                           y: centerY - diameter / 2, width: diameter, height: diameter))
        }
    }

}

@MainActor
final class MuscleCompositionCache {
    enum Layer: String {
        case complete, silhouette, highlights
    }

    static let shared = MuscleCompositionCache()
    private let images = NSCache<NSString, UIImage>()

    private init() {
        images.totalCostLimit = 4 * 1024 * 1024
        images.countLimit = 160
    }

    func image(for composition: MuscleComposition, size: CGSize, scale: CGFloat,
               isDark: Bool, layer: Layer = .complete) -> UIImage {
        let key = "\(size.width)x\(size.height)@\(scale)|\(isDark)|\(layer.rawValue)|\(composition.cacheKey)" as NSString
        if let image = images.object(forKey: key) { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.preferredRange = .standard
        let neutral = UIColor(white: isDark ? 0.36 : 0.78, alpha: 1)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            composition.draw(in: CGRect(origin: .zero, size: size), context: renderer.cgContext,
                             neutral: layer == .highlights ? nil : neutral,
                             highlightsOnly: layer == .highlights, silhouetteOnly: layer == .silhouette)
        }
        images.setObject(image, forKey: key, cost: (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0))
        return image
    }
}

/// Exercise cards and Live Activities share a single cached texture.
struct ComposedMuscleIcon: View {
    let composition: MuscleComposition
    let size: CGSize
    @Environment(\.displayScale) private var scale
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(uiImage: MuscleCompositionCache.shared.image(for: composition, size: size, scale: scale,
                                                           isDark: colorScheme == .dark))
            .accessibilityHidden(true)
    }
}

/// The wheel animates the tint of a cached highlight mask as selection changes.
struct TintedMuscleComposition: View {
    let icons: [MuscleIcon]
    let color: Color
    @Environment(\.displayScale) private var scale
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let composition = MuscleComposition(highlights: icons.map { .init(icon: $0, colorHex: "FFFFFF") })
        let size = CGSize(width: 48, height: 48)
        let cache = MuscleCompositionCache.shared
        ZStack {
            Image(uiImage: cache.image(for: composition, size: size, scale: scale,
                                       isDark: colorScheme == .dark, layer: .silhouette))
                .resizable()
                .scaledToFit()
            Image(uiImage: cache.image(for: composition, size: size, scale: scale, isDark: false, layer: .highlights))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }
}

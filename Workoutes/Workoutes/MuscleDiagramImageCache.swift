import SwiftUI
import UIKit

struct MuscleDiagramStyle {
    let colorScheme: ColorScheme
    let contrast: ColorSchemeContrast
    let dynamicTypeSize: DynamicTypeSize
    let locale: Locale
    let scale: CGFloat

    var background: Color {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = colorScheme == .dark ? .dark : .light
            traits.accessibilityContrast = contrast == .increased ? .high : .normal
        }
        return Color(uiColor: UIColor.secondarySystemGroupedBackground.resolvedColor(with: traits))
    }
}

/// Keeps the entire noninteractive plot in one opaque texture. Counts and palette changes
/// invalidate it; moving back into the viewport does not require another diagram layout.
@MainActor
final class MuscleDiagramImageCache {
    static let shared = MuscleDiagramImageCache()
    private let images = NSCache<NSString, UIImage>()

    init() {
        images.totalCostLimit = 32 * 1024 * 1024
        images.countLimit = 12
    }

    func image<Content: View>(activity: WeeklyMuscleActivity, size: CGSize, badgeHeight: CGFloat,
                             style: MuscleDiagramStyle, @ViewBuilder content: () -> Content) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = max(1, style.scale)
        let width = (size.width * scale).rounded()
        let height = (size.height * scale).rounded()
        let key = "\(width)x\(height)@\(scale)|\(badgeHeight)|\(style.colorScheme)|\(style.contrast)|\(style.dynamicTypeSize)|\(style.locale.identifier)|\(activity.diagramSignature)" as NSString
        if let image = images.object(forKey: key) { return image }
        let renderer = ImageRenderer(content: content()
            .frame(width: width / scale, height: height / scale)
            .background(style.background)
            .environment(\.colorScheme, style.colorScheme)
            .environment(\.dynamicTypeSize, style.dynamicTypeSize)
            .environment(\.displayScale, scale)
            .environment(\.locale, style.locale))
        renderer.scale = scale
        renderer.isOpaque = true
        guard let image = renderer.uiImage else { return nil }
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        images.setObject(image, forKey: key, cost: cost)
        return image
    }
}

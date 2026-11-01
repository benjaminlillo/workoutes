import SwiftUI
import UIKit

/// Anatomical masks are static during scrolling. Compose them once at display resolution;
/// the live view then displays one texture per body instead of dozens of template/gradient layers.
@MainActor
final class MuscleBodyImageCache {
    static let shared = MuscleBodyImageCache()
    private let images = NSCache<NSString, UIImage>()

    init() {
        images.totalCostLimit = 24 * 1024 * 1024
        images.countLimit = 64
    }

    func image(side: MuscleBodySide, activity: WeeklyMuscleActivity, size: CGSize,
               scale: CGFloat, isDark: Bool) -> UIImage {
        let scale = max(1, scale)
        let size = CGSize(width: max(1, (size.width * scale).rounded()) / scale,
                          height: max(1, (size.height * scale).rounded()) / scale)
        let layers = side.regions.compactMap { region -> (String, [String])? in
            let colors = activity.entries(for: region, on: side).map { $0.colorHex ?? "808080" }
            return colors.isEmpty ? nil : (region, colors)
        }
        // Counts and tag names do not change the body's pixels, and must not invalidate it.
        let palette = layers.map { "\($0.0):\($0.1.joined(separator: ","))" }.joined(separator: ";")
        let key = "\(side.rawValue)|\(size.width)x\(size.height)@\(scale)|\(isDark)|\(palette)" as NSString
        if let image = images.object(forKey: key) { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.preferredRange = .standard
        let bounds = CGRect(origin: .zero, size: size)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            UIImage(named: side.asset("base"))?
                .withTintColor(UIColor(white: isDark ? 0.30 : 0.84, alpha: 1), renderingMode: .alwaysOriginal)
                .draw(in: bounds)
            for (region, hexColors) in layers {
                guard let mask = UIImage(named: side.asset(region)) else { continue }
                let colors = hexColors.map { UIColor(Color(hex: $0)) }
                if colors.count == 1 {
                    mask.withTintColor(colors[0], renderingMode: .alwaysOriginal).draw(in: bounds)
                } else {
                    draw(mask: mask, colors: colors, in: bounds, context: renderer.cgContext)
                }
            }
        }
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        images.setObject(image, forKey: key, cost: cost)
        return image
    }

    private func draw(mask: UIImage, colors: [UIColor], in bounds: CGRect, context: CGContext) {
        let stops = colors.enumerated().flatMap { index, color in
            [(color.cgColor, CGFloat(index) / CGFloat(colors.count)),
             (color.cgColor, CGFloat(index + 1) / CGFloat(colors.count))]
        }
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: stops.map(\.0) as CFArray, locations: stops.map(\.1)) else { return }
        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        mask.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: bounds)
        context.setBlendMode(.sourceIn)
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: bounds.width, y: 0), options: [])
        context.endTransparencyLayer()
        context.restoreGState()
    }
}

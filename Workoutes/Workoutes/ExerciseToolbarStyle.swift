import SwiftUI
import UIKit

enum ExerciseToolbarStyle {
    static let symbolSize: CGFloat = 22
    static let targetSize: CGFloat = 44

    static var symbolConfiguration: UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium, scale: .medium)
    }

    static func symbol(_ name: String) -> UIImage? {
        guard let image = UIImage(systemName: name, withConfiguration: symbolConfiguration) else { return nil }
        // Match visible bounds across symbols and keep both rendering paths centered.
        let opticalSize: CGFloat = 24
        let bounds = CGRect(origin: .zero, size: image.size).inset(by: image.alignmentRectInsets)
        let scale = opticalSize / max(bounds.width, bounds.height)
        let canvas = CGSize(width: 30, height: 30)
        let rect = CGRect(x: canvas.width / 2 - bounds.midX * scale,
                          y: canvas.height / 2 - bounds.midY * scale,
                          width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: canvas).image { _ in
            image.draw(in: rect)
        }.withRenderingMode(.alwaysTemplate)
    }
}

struct ExerciseToolbarLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            if let symbol = ExerciseToolbarStyle.symbol(systemImage) {
                Image(uiImage: symbol)
                    .renderingMode(.template)
            }
        }
        .labelStyle(.iconOnly)
        .frame(width: ExerciseToolbarStyle.targetSize, height: ExerciseToolbarStyle.targetSize)
    }
}

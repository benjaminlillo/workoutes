import SwiftUI
import UIKit

enum ExerciseToolbarStyle {
    static let symbolSize: CGFloat = 18
    static let targetSize: CGFloat = 44

    static var symbolConfiguration: UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium, scale: .medium)
    }
}

struct ExerciseToolbarLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: ExerciseToolbarStyle.symbolSize, weight: .medium))
                .imageScale(.medium)
                .symbolRenderingMode(.monochrome)
        }
        .labelStyle(.iconOnly)
        .frame(width: ExerciseToolbarStyle.targetSize, height: ExerciseToolbarStyle.targetSize)
    }
}

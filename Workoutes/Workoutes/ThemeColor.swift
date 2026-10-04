import SwiftUI
import UIKit

enum ThemeColor: String, CaseIterable, Identifiable {
    case primary, mint, blue, purple, orange, green, red, indigo
    
    var id: Self { self }
    
    var color: Color {
        switch self {
        case .primary: return Color(red: 50/255, green: 104/255, blue: 132/255)
        case .mint: return .mint
        case .blue: return .blue
        case .purple: return .purple
        case .orange: return .orange
        case .green: return .green
        case .red: return .red
        case .indigo: return .indigo
        }
    }
    
    var name: String {
        self.rawValue.capitalized
    }

    /// Two pastel shades of the accent, softened again by the background renderer.
    var defaultGradientColors: [String] {
        let accent = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        guard accent.getRed(&red, green: &green, blue: &blue, alpha: nil) else {
            return [color.toHex()]
        }
        return [0.35, 0.5].map { strength in
            Color(red: 1 - Double(1 - red) * strength,
                  green: 1 - Double(1 - green) * strength,
                  blue: 1 - Double(1 - blue) * strength).toHex()
        }
    }
}

import SwiftUI
import UIKit

enum ThemeColor: String, CaseIterable, Identifiable {
    // Preserve the stored identifiers for existing selections.
    case primary, indigo, mint, purple, orange
    
    var id: Self { self }
    
    var hex: String {
        switch self {
        case .primary: "326884"
        case .indigo: "6155F5"
        case .mint: "D2F1E4"
        case .purple: "42213D"
        case .orange: "F15025"
        }
    }

    var color: Color { Color(hex: hex) }
    
    var name: String {
        switch self {
        case .primary: "Blue Slate"
        case .indigo: "Majorelle Blue"
        case .mint: "Frozen Water"
        case .purple: "Midnight Violet"
        case .orange: "Blazing Flame"
        }
    }

    static func resolve(_ rawValue: String?) -> Self {
        if let rawValue, let theme = Self(rawValue: rawValue) { return theme }
        switch rawValue {
        case "blue": return .indigo
        case "green": return .mint
        case "red": return .orange
        default: return .primary
        }
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

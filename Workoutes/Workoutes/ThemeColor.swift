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
        case .mint: "92DDBE"
        case .purple: "42213D"
        case .orange: "F15025"
        }
    }

    func hex(for scheme: ColorScheme) -> String {
        guard scheme == .dark else { return hex }
        switch self {
        case .mint: return "D2F1E4"
        case .purple: return "88447E"
        default: return hex
        }
    }

    var color: Color {
        let light = UIColor(Color(hex: hex(for: .light)))
        let dark = UIColor(Color(hex: hex(for: .dark)))
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
    
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
    func defaultGradientColors(for scheme: ColorScheme) -> [String] {
        let accent = UIColor(Color(hex: hex(for: scheme)))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        guard accent.getRed(&red, green: &green, blue: &blue, alpha: nil) else {
            return [hex(for: scheme)]
        }
        return [0.35, 0.5].map { strength in
            Color(red: 1 - Double(1 - red) * strength,
                  green: 1 - Double(1 - green) * strength,
                  blue: 1 - Double(1 - blue) * strength).toHex()
        }
    }
}

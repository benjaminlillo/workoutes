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

    /// Used only as the second color of the theme's default background gradient.
    var secondaryHex: String {
        switch self {
        case .primary: "63B7AF"
        case .indigo: "AB78DD"
        case .mint: "83C8DB"
        case .purple: "C27D98"
        case .orange: "F5B84B"
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

    /// Pastel versions of the theme's primary and secondary colors.
    func defaultGradientColors(for scheme: ColorScheme) -> [String] {
        zip([hex(for: scheme), secondaryHex], [0.35, 0.5]).map { hex, strength in
            let color = UIColor(Color(hex: hex))
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: nil) else { return hex }
            return Color(red: 1 - Double(1 - red) * strength,
                         green: 1 - Double(1 - green) * strength,
                         blue: 1 - Double(1 - blue) * strength).toHex()
        }
    }
}

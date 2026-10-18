import SwiftUI
import UIKit

enum ThemeColor: String, CaseIterable, Identifiable {
    // Preserve the stored identifiers for existing selections.
    case primary, indigo, mint, purple, orange, electricRush, sunsetPop
    case ultravolt, cobaltHeat, cherryIce, midnightGold
    
    var id: Self { self }
    
    var hex: String {
        switch self {
        case .primary: "176B87"
        case .indigo: "6C3DD1"
        case .mint: "2F6B4F"
        case .purple: "8A3D65"
        case .orange: "C9562D"
        case .electricRush: "3D52F5"
        case .sunsetPop: "D12D78"
        case .ultravolt: "5621B6"
        case .cobaltHeat: "1745A3"
        case .cherryIce: "AE194F"
        case .midnightGold: "1C2D50"
        }
    }

    func hex(for scheme: ColorScheme) -> String {
        scheme == .dark ? secondaryHex : hex
    }

    /// A lighter accent for dark surfaces and the first color of the background gradient.
    var secondaryHex: String {
        switch self {
        case .primary: "64CCC5"
        case .indigo: "B784E8"
        case .mint: "8FC7A1"
        case .purple: "C77C9B"
        case .orange: "EBA66B"
        case .electricRush: "32D5E5"
        case .sunsetPop: "FF8059"
        case .ultravolt: "B9EE4A"
        case .cobaltHeat: "FF985C"
        case .cherryIce: "55D6CF"
        case .midnightGold: "F6C85F"
        }
    }

    /// The supporting color of the theme's background gradient.
    var tertiaryHex: String {
        switch self {
        case .primary: "DAFFFB"
        case .indigo: "F3DDF2"
        case .mint: "E6EFD8"
        case .purple: "F2D6DE"
        case .orange: "F6E5CF"
        case .electricRush: "D5F66A"
        case .sunsetPop: "FFD65C"
        case .ultravolt: "F0FFD0"
        case .cobaltHeat: "FFF1CB"
        case .cherryIce: "D9FFF7"
        case .midnightGold: "FFF1C7"
        }
    }

    var alternateIconName: String? {
        switch self {
        case .primary: nil
        case .indigo: "WorkoutesIcon-majorelle-blue"
        case .mint: "WorkoutesIcon-frozen-water"
        case .purple: "WorkoutesIcon-midnight-violet"
        case .orange: "WorkoutesIcon-blazing-flame"
        case .electricRush: "WorkoutesIcon-electric-rush"
        case .sunsetPop: "WorkoutesIcon-sunset-pop"
        case .ultravolt: "WorkoutesIcon-ultravolt"
        case .cobaltHeat: "WorkoutesIcon-cobalt-heat"
        case .cherryIce: "WorkoutesIcon-cherry-ice"
        case .midnightGold: "WorkoutesIcon-midnight-gold"
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
        case .primary: "Ocean Pulse"
        case .indigo: "Violet Aura"
        case .mint: "Matcha Club"
        case .purple: "Rosewood"
        case .orange: "Ember Glow"
        case .electricRush: "Electric Rush"
        case .sunsetPop: "Sunset Pop"
        case .ultravolt: "Ultravolt"
        case .cobaltHeat: "Cobalt Heat"
        case .cherryIce: "Cherry Ice"
        case .midnightGold: "Midnight Gold"
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

    /// Both appearances use the palette's complement and supporting color.
    func defaultGradientColors(for _: ColorScheme) -> [String] {
        [secondaryHex, tertiaryHex]
    }
}

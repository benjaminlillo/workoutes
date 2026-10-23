import SwiftUI
import UIKit

enum ThemeColor: String, CaseIterable, Identifiable {
    // Preserve the stored identifiers for existing selections.
    case indigo, electricRush, sunsetPop
    case ultravolt, cobaltHeat, cherryIce, midnightGold
    
    var id: Self { self }
    
    var hex: String {
        switch self {
        case .indigo: "6C3DD1"
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
        case .indigo: "B784E8"
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
        case .indigo: "F3DDF2"
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
        case .indigo: nil
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
        case .indigo: "Violet Aura"
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
        // Retired palettes and older aliases migrate to Violet Aura.
        return .indigo
    }

    /// Both appearances use the full palette for the atmospheric background.
    func defaultGradientColors(for _: ColorScheme) -> [String] {
        [hex, secondaryHex, tertiaryHex]
    }
}

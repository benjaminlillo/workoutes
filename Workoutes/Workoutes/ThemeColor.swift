import SwiftUI
import UIKit

enum ThemeColor: String, CaseIterable, Identifiable {
    // Preserve the stored identifiers for existing selections.
    case indigo, electricRush, sunsetPop
    case ultravolt, cobaltHeat, cherryIce, midnightGold
    case aurora, solarFlare, tropicPunch, mintBerry
    
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
        case .aurora: "1F6F6B"
        case .solarFlare: "C2410C"
        case .tropicPunch: "0E7C7B"
        case .mintBerry: "9C1F6E"
        }
    }

    func hex(for scheme: ColorScheme) -> String {
        scheme == .dark ? secondaryHex : hex
    }

    /// A lighter accent for dark surfaces and the upper-right background field.
    var secondaryHex: String {
        switch self {
        case .indigo: "B784E8"
        case .electricRush: "32D5E5"
        case .sunsetPop: "FF8059"
        case .ultravolt: "B9EE4A"
        case .cobaltHeat: "FF985C"
        case .cherryIce: "55D6CF"
        case .midnightGold: "F6C85F"
        case .aurora: "9B7BFF"
        case .solarFlare: "7C5CFF"
        case .tropicPunch: "FF6B8B"
        case .mintBerry: "5FE3A1"
        }
    }

    /// The supporting color available for custom gradients and icon artwork.
    var tertiaryHex: String {
        switch self {
        case .indigo: "F3DDF2"
        case .electricRush: "D5F66A"
        case .sunsetPop: "FFD65C"
        case .ultravolt: "F0FFD0"
        case .cobaltHeat: "FFF1CB"
        case .cherryIce: "D9FFF7"
        case .midnightGold: "FFF1C7"
        case .aurora: "D9FFE8"
        case .solarFlare: "EFE6FF"
        case .tropicPunch: "FFE8C2"
        case .mintBerry: "E6FFF0"
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
        case .aurora: "WorkoutesIcon-aurora"
        case .solarFlare: "WorkoutesIcon-solar-flare"
        case .tropicPunch: "WorkoutesIcon-tropic-punch"
        case .mintBerry: "WorkoutesIcon-mint-berry"
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
        case .indigo: String(localized: "Violet Aura")
        case .electricRush: String(localized: "Electric Rush")
        case .sunsetPop: String(localized: "Sunset Pop")
        case .ultravolt: String(localized: "Ultravolt")
        case .cobaltHeat: String(localized: "Cobalt Heat")
        case .cherryIce: String(localized: "Cherry Ice")
        case .midnightGold: String(localized: "Midnight Gold")
        case .aurora: String(localized: "Aurora")
        case .solarFlare: String(localized: "Solar Flare")
        case .tropicPunch: String(localized: "Tropic Punch")
        case .mintBerry: String(localized: "Mint Berry")
        }
    }

    static func resolve(_ rawValue: String?) -> Self {
        if let rawValue, let theme = Self(rawValue: rawValue) { return theme }
        // Retired palettes and older aliases migrate to Violet Aura.
        return .indigo
    }

    func backgroundBaseHex(for scheme: ColorScheme) -> String {
        switch self {
        case .indigo: scheme == .dark ? "0C0B12" : "F8F7FA"
        case .electricRush: scheme == .dark ? "090D14" : "F7F9FA"
        case .sunsetPop: scheme == .dark ? "110C10" : "FAF8F6"
        case .ultravolt: scheme == .dark ? "0C0D12" : "F8F9F6"
        case .cobaltHeat: scheme == .dark ? "090E18" : "F9F9F7"
        case .cherryIce: scheme == .dark ? "0B0E13" : "F7FAF9"
        case .midnightGold: scheme == .dark ? "090E18" : "FAF9F5"
        case .aurora: scheme == .dark ? "0A0E10" : "F6FAF9"
        case .solarFlare: scheme == .dark ? "110C0C" : "FAF8F7"
        case .tropicPunch: scheme == .dark ? "0A0F10" : "FAF9F6"
        case .mintBerry: scheme == .dark ? "0F0B10" : "F7FAF8"
        }
    }

    /// The complete palette remains available in the background editor.
    func defaultGradientColors(for _: ColorScheme) -> [String] {
        [hex, secondaryHex, tertiaryHex]
    }
}

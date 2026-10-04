import SwiftUI

/// Spreads the selected theme across the screen, independently of saved customization.
struct DefaultScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue

    var body: some View {
        LinearGradient(
            colors: ThemeColor.resolve(accentColorRawValue).defaultGradientColors(for: colorScheme).map { Color(hex: $0) },
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
            .opacity(colorScheme == .dark ? 0.5 : 0.4)
            .background {
                colorScheme == .dark
                    ? Color(red: 0.035, green: 0.04, blue: 0.055)
                    : Color.white
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    func defaultScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background { DefaultScreenBackground().ignoresSafeArea() }
    }
}

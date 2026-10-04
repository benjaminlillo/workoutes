import SwiftUI

/// Spreads the selected theme across the screen, independently of saved customization.
struct DefaultScreenBackground: View {
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue

    var body: some View {
        ThemeBackgroundGradient(theme: ThemeColor.resolve(accentColorRawValue))
    }
}

/// The same background renderer is used for app screens and independent theme previews.
struct ThemeBackgroundGradient: View {
    let theme: ThemeColor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: theme.defaultGradientColors(for: colorScheme).map { Color(hex: $0) },
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

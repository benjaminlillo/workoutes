import SwiftUI

/// Spreads the selected theme across the screen, independently of saved customization.
struct DefaultScreenBackground: View {
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.indigo.rawValue

    var body: some View {
        ThemeBackgroundGradient(theme: ThemeColor.resolve(accentColorRawValue))
    }
}

/// The same background renderer is used for app screens and independent theme previews.
struct ThemeBackgroundGradient: View {
    let theme: ThemeColor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AtmosphericBackgroundGradient(colors: theme.defaultGradientColors(for: colorScheme))
    }
}

extension View {
    func defaultScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background { DefaultScreenBackground().ignoresSafeArea() }
    }
}

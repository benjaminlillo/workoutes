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

    var body: some View {
        ThemeAtmosphericBackground(theme: theme)
    }
}

extension View {
    func defaultScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background { DefaultScreenBackground().ignoresSafeArea() }
    }
}

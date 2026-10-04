import SwiftUI

/// Follows the app accent, independently of any screen's saved customization.
struct DefaultScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue

    var body: some View {
        SoftBackgroundGradient(colors: ThemeColor.resolve(accentColorRawValue).defaultGradientColors(for: colorScheme))
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

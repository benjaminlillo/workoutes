import SwiftUI

/// Follows the app accent, independently of any screen's saved customization.
struct DefaultScreenBackground: View {
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue

    var body: some View {
        SoftBackgroundGradient(colors: ThemeColor.resolve(accentColorRawValue).defaultGradientColors)
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

import SwiftUI

/// Uses the built-in palette, independently of any screen's saved customization.
struct DefaultScreenBackground: View {
    var body: some View {
        SoftBackgroundGradient(colors: ExerciseBackgroundStore.defaultGradientColors)
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

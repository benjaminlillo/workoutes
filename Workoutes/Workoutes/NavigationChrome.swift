import SwiftUI

extension View {
    /// Lets scrolling content continue beneath a transparent navigation bar with a soft top fade.
    func transparentNavigationChrome() -> some View {
        scrollEdgeEffectStyle(.soft, for: .top)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

import SwiftUI

extension View {
    func stableBottomOverlay<Overlay: View>(bottomInset: CGFloat = 0, bottomContentMargin: CGFloat = 0,
                                           @ViewBuilder _ overlay: @escaping () -> Overlay) -> some View {
        modifier(StableBottomOverlayModifier(bottomInset: bottomInset,
                                             bottomContentMargin: bottomContentMargin, overlay: overlay))
    }
}

/// Anchors floating controls to the window's bottom edge, independently of bar minimization.
private struct StableBottomOverlayModifier<Overlay: View>: ViewModifier {
    let bottomInset: CGFloat
    let bottomContentMargin: CGFloat
    let overlay: () -> Overlay

    func body(content: Content) -> some View {
        content
            .contentMargins(.bottom, bottomContentMargin, for: .scrollContent)
            .overlay(alignment: .bottomTrailing) {
                overlay()
                    .padding(.bottom, bottomInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
    }
}

import SwiftUI

extension View {
    func stableBottomOverlay<Overlay: View>(bottomContentMargin: CGFloat = 0,
                                           @ViewBuilder _ overlay: @escaping () -> Overlay) -> some View {
        modifier(StableBottomOverlayModifier(bottomContentMargin: bottomContentMargin, overlay: overlay))
    }
}

/// Keeps floating controls at the expanded bar's height while its bottom safe area contracts.
private struct StableBottomOverlayModifier<Overlay: View>: ViewModifier {
    let bottomContentMargin: CGFloat
    let overlay: () -> Overlay
    @State private var reference: BottomOverlayGeometry?
    @State private var correction: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.bottom, bottomContentMargin - correction, for: .scrollContent)
            .background {
                GeometryReader { geometry in
                    Color.clear.onChange(of: BottomOverlayGeometry(geometry), initial: true) { _, value in
                        if reference?.viewport != value.viewport || value.bottomInset > (reference?.bottomInset ?? 0) {
                            reference = value
                        }
                        correction = value.bottomInset - (reference?.bottomInset ?? value.bottomInset)
                    }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                overlay().offset(y: correction)
            }
    }
}

private struct BottomOverlayGeometry: Equatable {
    let viewport: CGSize
    let bottomInset: CGFloat

    init(_ geometry: GeometryProxy) {
        bottomInset = geometry.safeAreaInsets.bottom
        // Unlike the list's height, these dimensions don't change when either navigation bar collapses.
        viewport = CGSize(width: geometry.size.width.rounded(),
                          height: (geometry.frame(in: .global).maxY + bottomInset).rounded())
    }
}

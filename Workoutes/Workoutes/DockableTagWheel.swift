import SwiftData
import SwiftUI
import UIKit

struct DockableTagWheel: View {
    let tags: [Tag]
    @Binding var selection: PersistentIdentifier?
    let onAdd: () -> Void
    let onEdit: (Tag) -> Void
    let onDelete: (Tag) -> Void

    static let coordinateSpace = "dockable-tag-wheel"
    static let hubInset: CGFloat = 34
    @AppStorage("tagWheelDockPosition") private var storedPosition = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var windowInsets = UIEdgeInsets.zero
    @State private var dragOrigin: CGPoint?
    @State private var translation = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            let bounds = centerBounds(size: geometry.size)
            let dock = TagWheelDock.decode(storedPosition) ?? defaultDock(size: geometry.size, bounds: bounds)
            let restCenter = dock.center(in: bounds)
            let center = TagWheelDock.clamped(CGPoint(x: (dragOrigin ?? restCenter).x + translation.width,
                                                      y: (dragOrigin ?? restCenter).y + translation.height), in: bounds)
            TagWheelPicker(tags: tags, selection: $selection, onAdd: onAdd, onEdit: onEdit, onDelete: onDelete,
                           screenCenter: center, selectionAngle: dock.selectionAngle,
                           onMove: { delta in
                               if dragOrigin == nil { dragOrigin = restCenter }
                               translation = delta
                           }, onMoveEnded: { delta in
                               let origin = dragOrigin ?? restCenter
                               let end = CGPoint(x: origin.x + delta.width, y: origin.y + delta.height)
                               let destination = TagWheelDock.nearest(to: end, in: bounds, preferredEdge: dock.edge)
                               withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86)) {
                                   storedPosition = destination.encoded
                                   dragOrigin = nil
                                   translation = .zero
                               }
                           }, onMoveCancelled: cancelMove, onDock: { edge in
                               let fraction = edge == .leading || edge == .trailing
                                   ? (bounds.height > 0 ? (center.y - bounds.minY) / bounds.height : 0.5)
                                   : (bounds.width > 0 ? (center.x - bounds.minX) / bounds.width : 0.5)
                               withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86)) {
                                   storedPosition = TagWheelDock(edge: edge, fraction: fraction).encoded
                                   dragOrigin = nil
                                   translation = .zero
                               }
                           })
                .position(center)
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86), value: storedPosition)
                .onChange(of: geometry.size) { _, _ in cancelMove() }
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .background {
            WheelWindowInsets { windowInsets = $0 }
                .allowsHitTesting(false)
        }
        .ignoresSafeArea(.container)
        .onDisappear(perform: cancelMove)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelMove() }
        }
    }

    private func centerBounds(size: CGSize) -> CGRect {
        // Read the window's hardware insets, not the tab bar's changing safe area.
        // Reserve its expanded height so the hub never ends up underneath navigation.
        let left = min(size.width / 2, windowInsets.left + Self.hubInset)
        let right = max(left, size.width - windowInsets.right - Self.hubInset)
        let top = min(size.height / 2, windowInsets.top + Self.hubInset)
        let bottom = max(top, size.height - windowInsets.bottom - 64 - Self.hubInset)
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    private func defaultDock(size: CGSize, bounds: CGRect) -> TagWheelDock {
        let point = TagWheelDock.clamped(CGPoint(x: bounds.maxX,
                                                 y: size.height - TagWheelPicker.bottomInset - TagWheelPicker.diameter / 2),
                                        in: bounds)
        return TagWheelDock(edge: .trailing, fraction: bounds.height > 0 ? (point.y - bounds.minY) / bounds.height : 0.5)
    }

    private func cancelMove() {
        dragOrigin = nil
        translation = .zero
    }
}

private struct WheelWindowInsets: UIViewRepresentable {
    let onChange: (UIEdgeInsets) -> Void

    func makeUIView(context: Context) -> InsetsView {
        let view = InsetsView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: InsetsView, context: Context) { view.onChange = onChange }

    final class InsetsView: UIView {
        var onChange: ((UIEdgeInsets) -> Void)?
        private var previous: UIEdgeInsets?

        override func didMoveToWindow() { super.didMoveToWindow(); publishInsets() }
        override func layoutSubviews() { super.layoutSubviews(); publishInsets() }
        override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); publishInsets() }

        private func publishInsets() {
            guard let insets = window?.safeAreaInsets, insets != previous else { return }
            previous = insets
            DispatchQueue.main.async { [weak self] in self?.onChange?(insets) }
        }
    }
}

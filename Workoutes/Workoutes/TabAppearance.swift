import SwiftUI

/// A new activation replays the fade without replacing a tab's navigation or list state.
struct TabAppearanceActivation: Equatable {
    let id = UUID()
    let startedAt = Date.now
    var isActive = true
}

private struct TabAppearanceKey: EnvironmentKey {
    static let defaultValue: TabAppearanceActivation? = nil
}

extension EnvironmentValues {
    var tabAppearance: TabAppearanceActivation? {
        get { self[TabAppearanceKey.self] }
        set { self[TabAppearanceKey.self] = newValue }
    }
}

extension View {
    func tabAppearance(_ activation: TabAppearanceActivation, isActive: Bool) -> some View {
        var value = activation
        value.isActive = isActive
        return environment(\.tabAppearance, value)
    }

    func staggeredTabAppearance(onCompletion: ((TabAppearanceActivation) -> Void)? = nil) -> some View {
        modifier(StaggeredTabAppearance(onCompletion: onCompletion))
    }
}

/// Geometry is sampled without invalidating the view on every scroll frame.
@MainActor
private final class AppearancePosition {
    var top: CGFloat = 0
}

private struct StaggeredTabAppearance: ViewModifier {
    var onCompletion: ((TabAppearanceActivation) -> Void)?
    @Environment(\.tabAppearance) private var activation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position = AppearancePosition()
    @State private var isVisible = false

    private var showsContent: Bool {
        guard let activation else { return true }
        return reduceMotion || isVisible || Date.now.timeIntervalSince(activation.startedAt) >= 0.9
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: {
                position.top = $0
            }
            .opacity(showsContent ? 1 : 0)
            .allowsHitTesting(showsContent)
            .accessibilityHidden(!showsContent)
            .task(id: activation) {
                reset()
                guard let activation, activation.isActive else { return }
                guard !reduceMotion else {
                    isVisible = true
                    onCompletion?(activation)
                    return
                }

                do {
                    // Wait one frame for the incoming tab's visible geometry.
                    try await Task.sleep(for: .milliseconds(16))
                    let elapsed = Date.now.timeIntervalSince(activation.startedAt)
                    // Rows loaded later by scrolling or editing stay immediately visible.
                    guard elapsed < 0.9 else {
                        isVisible = true
                        onCompletion?(activation)
                        return
                    }
                    // Screen position also orders a list that was left scrolled down.
                    let delay = min(0.42, max(0, Double(position.top - 120) * 0.00055))
                    let remaining = max(0, delay - elapsed)
                    if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
                    try Task.checkCancellation()
                    withAnimation(.easeOut(duration: 0.28)) {
                        isVisible = true
                    } completion: {
                        onCompletion?(activation)
                    }
                } catch {
                    // Switching tabs cancels unfinished appearances.
                }
            }
            .onDisappear { reset() }
    }

    private func reset() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { isVisible = false }
    }
}

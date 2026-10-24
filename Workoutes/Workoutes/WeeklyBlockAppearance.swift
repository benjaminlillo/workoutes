import SwiftUI

/// The chart container publishes this only when its own fade has finished.
struct WeeklyBlockAppearance: Equatable {
    let activationID: UUID
    let startedAt = Date.now
}

private struct WeeklyBlockAppearanceKey: EnvironmentKey {
    static let defaultValue: WeeklyBlockAppearance? = nil
}

extension EnvironmentValues {
    var weeklyBlockAppearance: WeeklyBlockAppearance? {
        get { self[WeeklyBlockAppearanceKey.self] }
        set { self[WeeklyBlockAppearanceKey.self] = newValue }
    }
}

struct WeeklyBlockFade: ViewModifier {
    let level: Int
    let levelCount: Int
    @Environment(\.tabAppearance) private var activation
    @Environment(\.weeklyBlockAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private var showsContent: Bool {
        guard let activation else { return true }
        if reduceMotion { return true }
        guard let appearance, appearance.activationID == activation.id else { return false }
        return isVisible || Date.now.timeIntervalSince(appearance.startedAt) >= 0.9
    }

    func body(content: Content) -> some View {
        content
            .opacity(showsContent ? 1 : 0)
            .allowsHitTesting(showsContent)
            .accessibilityHidden(!showsContent)
            .task(id: [activation?.id, appearance?.activationID]) {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) { isVisible = false }
                guard let activation, activation.isActive,
                      let appearance, appearance.activationID == activation.id else { return }
                guard !reduceMotion else { isVisible = true; return }
                let elapsed = Date.now.timeIntervalSince(appearance.startedAt)
                guard elapsed < 0.9 else { isVisible = true; return }
                // Each horizontal level appears together, starting at the chart's baseline.
                let step = min(0.07, 0.42 / Double(max(1, levelCount - 1)))
                let delay = max(0, Double(level) * step - elapsed)
                do {
                    // Let the hidden state reach the screen before starting the first level.
                    try await Task.sleep(for: .seconds(max(0.016, delay)))
                    try Task.checkCancellation()
                    withAnimation(.easeOut(duration: 0.28)) { isVisible = true }
                } catch {
                    // A tab change cancels any unrevealed blocks.
                }
            }
    }
}

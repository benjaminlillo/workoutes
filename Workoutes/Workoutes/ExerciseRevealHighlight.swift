import SwiftUI

struct ExerciseRevealHighlight: View {
    let color: Color
    let trigger: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(color.opacity(0.1))
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { highlight, opacity in
                highlight.opacity(trigger == nil ? 0 : opacity)
            } keyframes: { _ in
                CubicKeyframe(1.0, duration: 0.5)
                CubicKeyframe(reduceMotion ? 1.0 : 0.0, duration: 0.5)
                CubicKeyframe(1.0, duration: 0.5)
                CubicKeyframe(reduceMotion ? 1.0 : 0.0, duration: 0.5)
                CubicKeyframe(1.0, duration: 0.5)
                CubicKeyframe(0.0, duration: 0.5)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

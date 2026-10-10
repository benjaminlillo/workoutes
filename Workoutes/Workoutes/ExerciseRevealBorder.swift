import SwiftUI

struct ExerciseRevealBorder: View {
    let color: Color
    let trigger: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(color, lineWidth: 3)
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { border, opacity in
                border.opacity(trigger == nil ? 0 : opacity)
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

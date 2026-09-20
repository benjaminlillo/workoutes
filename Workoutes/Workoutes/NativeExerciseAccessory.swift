import SwiftUI

/// Content for the tab view's native bottom accessory.
struct NativeExerciseAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    let content: ExerciseActivityAttributes.ContentState?
    let isUpdating: Bool
    let accentColor: Color
    let onStop: () -> Void

    var body: some View {
        ActiveExerciseBar(
            exercise: content,
            isCompact: placement == .inline,
            isUpdating: isUpdating,
            onStop: onStop
        )
        .tint(accentColor)
    }
}

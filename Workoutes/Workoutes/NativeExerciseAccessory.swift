import SwiftUI

/// Content for the tab view's native bottom accessory.
struct NativeExerciseAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    let content: ExerciseActivityAttributes.ContentState?
    let isUpdating: Bool
    let accentColor: Color
    let onShow: () -> Void
    let onStop: () -> Void

    var body: some View {
        ActiveExerciseBar(
            exercise: content,
            isCompact: placement == .inline,
            isUpdating: isUpdating,
            onShow: onShow,
            onStop: onStop
        )
        .tint(accentColor)
    }
}

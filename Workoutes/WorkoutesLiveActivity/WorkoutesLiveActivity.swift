import ActivityKit
import SwiftUI
import WidgetKit

@main
struct WorkoutesWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExerciseLiveActivity()
    }
}

struct ExerciseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExerciseActivityAttributes.self) { context in
            ExerciseActivitySummary(state: context.state)
                .padding(16)
                // Use a matching, explicit foreground/background pair: the Lock Screen
                // can supply a different color scheme from the app's UIKit colors.
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ExerciseActivitySummary(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text(context.state.title)
                    .lineLimit(1)
                    .frame(maxWidth: 100)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview("Active Exercise", as: .content, using: ExerciseActivityAttributes()) {
    ExerciseLiveActivity()
} contentStates: {
    ExerciseActivityAttributes.ContentState(
        exerciseID: "preview", title: "Bench Press", subtitle: "Controlled movement",
        numberOfSets: 3, reps: 10, weight: 32.5, increaseLoadNextTime: true,
        details: "Pause at the bottom", tagColors: ["FF8800", "5599FF"],
        accentColorHex: "326884", displayedWeight: 32.5, weightUnitSymbol: "kg", status: .playing
    )
    ExerciseActivityAttributes.ContentState(
        exerciseID: "preview", title: "Bench Press", subtitle: "Controlled movement",
        numberOfSets: 3, reps: 10, weight: 32.5, increaseLoadNextTime: true,
        accentColorHex: "326884", displayedWeight: 32.5, weightUnitSymbol: "kg", status: .done
    )
    ExerciseActivityAttributes.ContentState(
        exerciseID: "preview", title: "Bench Press", subtitle: "Controlled movement",
        numberOfSets: 3, reps: 10, weight: 32.5, increaseLoadNextTime: false,
        accentColorHex: "326884", displayedWeight: 32.5, weightUnitSymbol: "kg", status: .empty
    )
}

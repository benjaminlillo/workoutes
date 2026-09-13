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
                .activityBackgroundTint(Color(red: 0.08, green: 0.11, blue: 0.16))
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

private struct ExerciseActivitySummary: View {
    let state: ExerciseActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.title)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 24) {
                Text("Sets: \(state.numberOfSets)")
                Text("Reps: \(state.reps)")
            }
            .font(.subheadline.weight(.semibold).monospacedDigit())

            Label(
                state.increaseLoadNextTime ? "Increase Next: Yes" : "Increase Next: No",
                systemImage: state.increaseLoadNextTime ? "arrow.up.circle.fill" : "minus.circle"
            )
            .font(.subheadline)
            .foregroundStyle(state.increaseLoadNextTime ? Color.mint : Color.white.opacity(0.8))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

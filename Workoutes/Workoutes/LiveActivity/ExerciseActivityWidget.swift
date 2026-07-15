import WidgetKit
import SwiftUI
import ActivityKit

struct ExerciseActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExerciseAttributes.self) { context in
            // Lock Screen / Banner UI
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title.isEmpty ? "Exercise" : context.attributes.title)
                    .font(.headline)
                Text("\(context.state.sets) Sets • \(context.state.reps) Reps • \(Int(context.state.weight)) kg")
                    .font(.subheadline)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.orange)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.title.isEmpty ? "Exercise" : context.attributes.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.weight)) kg")
                        .foregroundColor(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.sets) Sets • \(context.state.reps) Reps")
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                Text("\(Int(context.state.weight))")
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(.orange)
            }
            .keylineTint(Color.orange)
        }
    }
}

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct WorkoutesWidgetBundle: WidgetBundle {
    var body: some Widget {
        SessionLiveActivity()
    }
}

struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            SessionActivitySummary(state: context.state)
                .padding(16)
                // Use a matching, explicit foreground/background pair: the Lock Screen
                // can supply a different color scheme from the app's UIKit colors.
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    SessionActivitySummary(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "figure.run")
                    .foregroundStyle(.white)
            } compactTrailing: {
                SessionCurrentTimeText(state: context.state, compact: true)
                    .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview("Flexible Session", as: .content, using: SessionActivityAttributes()) {
    SessionLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState(
        sessionID: "preview", blockID: "exercise", blockName: "Bench Press",
        blockKind: .exercise, blockStartedAt: .now.addingTimeInterval(-42),
        sessionStartedAt: .now.addingTimeInterval(-312), restEndsAt: nil,
        currentIndex: 2, totalBlocks: 5, isLastBlock: false, accentColorHex: "326884"
    )
}

import SwiftUI
import WidgetKit
import AppIntents

struct ExerciseActivitySummary: View {
    let state: ExerciseActivityAttributes.ContentState

    private var status: ExerciseStatus { state.status ?? .playing }
    private var accentColor: Color { Color(hex: state.accentColorHex ?? "B784E8") }

    var body: some View {
        ExerciseCardSurface {
            ExerciseCardHeader(
                title: state.title, subtitle: state.subtitle, details: state.details ?? "",
                increaseLoadNextTime: state.increaseLoadNextTime, accentColor: accentColor,
                tagColors: state.tagColors ?? [], tagIconNames: state.tagIconNames ?? []
            ) {
                statusControl
            }
            if state.isQueued == true {
                ExerciseQueuedLabel(number: state.queuedExerciseNumber, accentColor: accentColor)
            }

            Divider()

            ExerciseCardMetrics {
                ExerciseMetricView(
                    systemImage: "dumbbell.fill",
                    value: "\((state.displayedWeight ?? state.weight).formatted(.number.precision(.fractionLength(0...2)))) \(state.weightUnitSymbol ?? "kg")",
                    label: String(localized: "Weight")
                )
                .frame(maxWidth: .infinity, minHeight: 44)

            } sets: {
                ExerciseMetricView(
                    systemImage: "square.stack.3d.up.fill",
                    value: String(localized: "\(state.numberOfSets) sets"),
                    label: String(localized: "Sets")
                )
                .frame(maxWidth: .infinity, minHeight: 44)

            } repetitions: {
                ExerciseMetricView(
                    systemImage: "repeat",
                    value: String(localized: "\(state.reps) reps"),
                    label: String(localized: "Repetitions")
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            }

        }
        .foregroundStyle(.primary)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusControl: some View {
        if state.isQueued == true {
            ExerciseQueuedSymbol(accentColor: accentColor)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Exercise queued")
        } else if status == .playing {
            Button(intent: ExerciseLiveActivityIntent(exerciseID: state.exerciseID, sessionID: state.sessionID, complete: true)) {
                ExerciseStatusSymbol(status: status, accentColor: accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop active exercise")
            .accessibilityValue("Active")
        } else {
            ExerciseStatusSymbol(status: status, accentColor: accentColor)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(status == .done ? "Exercise completed" : "Exercise not started")
        }
    }
}

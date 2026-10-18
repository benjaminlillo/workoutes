import SwiftUI
import WidgetKit
import AppIntents

struct ExerciseActivitySummary: View {
    let state: ExerciseActivityAttributes.ContentState

    private var status: ExerciseStatus { state.status ?? .playing }
    private var accentColor: Color { Color(hex: state.accentColorHex ?? "64CCC5") }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ExerciseCardHeader(
                title: state.title, subtitle: state.subtitle, details: state.details ?? "",
                increaseLoadNextTime: state.increaseLoadNextTime, accentColor: accentColor,
                tagColors: state.tagColors ?? [], tagIconNames: state.tagIconNames ?? []
            ) {
                statusControl
            }

            Divider()

            HStack(spacing: 0) {
                ExerciseMetricView(
                    systemImage: "dumbbell.fill",
                    value: "\((state.displayedWeight ?? state.weight).formatted(.number.precision(.fractionLength(0...2)))) \(state.weightUnitSymbol ?? "kg")",
                    label: "Weight"
                )
                .frame(maxWidth: .infinity, minHeight: 44)

                metricDivider

                ExerciseMetricView(
                    systemImage: "square.stack.3d.up.fill",
                    value: "\(state.numberOfSets) sets",
                    label: "Sets"
                )
                .frame(maxWidth: .infinity, minHeight: 44)

                metricDivider

                ExerciseMetricView(
                    systemImage: "repeat",
                    value: "\(state.reps) reps",
                    label: "Repetitions"
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            }

        }
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusControl: some View {
        if status == .playing {
            Button(intent: ExerciseLiveActivityIntent(exerciseID: state.exerciseID, sessionID: state.sessionID, complete: true)) {
                ExerciseStatusSymbol(status: status, accentColor: accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop active exercise")
            .accessibilityValue(status.rawValue)
        } else {
            ExerciseStatusSymbol(status: status, accentColor: accentColor)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(status == .done ? "Exercise completed" : "Exercise not started")
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1, height: 42)
    }
}

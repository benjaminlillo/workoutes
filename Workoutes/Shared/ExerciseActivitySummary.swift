import SwiftUI
import WidgetKit
import AppIntents

struct ExerciseActivitySummary: View {
    let state: ExerciseActivityAttributes.ContentState

    private var status: ExerciseStatus { state.status ?? .playing }
    private var accentColor: Color { color(hex: state.accentColorHex ?? "326884") }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(state.title)
                        .font(.headline.weight(.bold))
                        .lineLimit(2)

                    if !state.subtitle.isEmpty {
                        Text(state.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    if let details = state.details, !details.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "doc.text")
                            Text(details)
                                .lineLimit(2)
                        }
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 8)

                VStack(spacing: 3) {
                    statusControl

                    HStack(spacing: 4) {
                        ForEach(Array((state.tagColors ?? []).enumerated()), id: \.offset) { _, hex in
                            Circle().fill(color(hex: hex)).frame(width: 7, height: 7)
                        }
                        if state.increaseLoadNextTime {
                            ExerciseBumpBadge(color: .white)
                        }
                    }
                    .fixedSize()
                }
                .frame(minWidth: 44)
            }

            Rectangle().fill(.white.opacity(0.2)).frame(height: 0.5)

            HStack(spacing: 0) {
                ExerciseMetricView(
                    systemImage: "dumbbell.fill",
                    value: "\((state.displayedWeight ?? state.weight).formatted(.number.precision(.fractionLength(0...2)))) \(state.weightUnitSymbol ?? "kg")",
                    label: "Weight"
                )

                metricDivider

                ExerciseMetricView(
                    systemImage: "square.stack.3d.up.fill",
                    value: "\(state.numberOfSets) sets",
                    label: "Sets"
                )

                metricDivider

                ExerciseMetricView(
                    systemImage: "repeat",
                    value: "\(state.reps) reps",
                    label: "Repetitions"
                )
            }

        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusControl: some View {
        if status == .playing {
            Button(intent: ExerciseLiveActivityIntent(exerciseID: state.exerciseID, complete: true)) {
                ExerciseStatusSymbol(status: status, accentColor: accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete active exercise")
            .accessibilityValue(status.rawValue)
        } else {
            ExerciseStatusSymbol(status: status, accentColor: accentColor)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(status == .done ? "Exercise completed" : "Exercise not started")
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.2))
            .frame(width: 1, height: 38)
    }

    private func color(hex: String) -> Color {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        return Color(.sRGB, red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255,
                     blue: Double(value & 255) / 255, opacity: 1)
    }
}

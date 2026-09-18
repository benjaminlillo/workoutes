import SwiftUI
import WidgetKit
import AppIntents

struct ExerciseActivitySummary: View {
    let state: ExerciseActivityAttributes.ContentState

    private var status: ExerciseStatus { state.status ?? .playing }
    private var accentColor: Color { color(hex: state.accentColorHex ?? "326884") }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(state.title)
                            .font(.headline)
                            .lineLimit(2)
                        ForEach(Array((state.tagColors ?? []).enumerated()), id: \.offset) { _, hex in
                            Circle().fill(color(hex: hex)).frame(width: 8, height: 8)
                        }
                    }
                    if !state.subtitle.isEmpty {
                        Text(state.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    if let details = state.details, !details.isEmpty {
                        Text(details)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(state.numberOfSets) Sets")
                    Text("\(state.reps) Reps")
                }
                .font(.subheadline.bold())
                .fixedSize()
            }

            Rectangle().fill(.white.opacity(0.2)).frame(height: 0.5)

            HStack {
                Text("\((state.displayedWeight ?? state.weight).formatted(.number.precision(.fractionLength(0...2)))) \(state.weightUnitSymbol ?? "kg")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityLabel("Weight")
                    .accessibilityValue("\((state.displayedWeight ?? state.weight).formatted()) \(state.weightUnitSymbol ?? "kg")")
                Spacer(minLength: 8)
                Button(intent: ExerciseLiveActivityIntent(exerciseID: state.exerciseID, complete: false)) {
                    Text("Increase Next")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(state.increaseLoadNextTime ? 1 : 0.6))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(status != .playing)
                .accessibilityValue(state.increaseLoadNextTime ? "On" : "Off")
                .accessibilityAddTraits(state.increaseLoadNextTime ? .isSelected : [])

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
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(hex: String) -> Color {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        return Color(.sRGB, red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255,
                     blue: Double(value & 255) / 255, opacity: 1)
    }
}

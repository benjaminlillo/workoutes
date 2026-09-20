import SwiftUI

struct ActiveExerciseBar: View {
    let exercise: ExerciseActivityAttributes.ContentState?
    let isCompact: Bool
    let isUpdating: Bool
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "dumbbell.fill")
                .font(.title3)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise?.title ?? "No Active Exercise")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if exercise != nil {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.body)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isUpdating)
                .accessibilityLabel("Stop active exercise")
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, isCompact ? 8 : 16)
        .padding(.trailing, 8)
        .padding(.vertical, isCompact ? 0 : 4)
        .accessibilityIdentifier("activeExerciseBar")
        // UITabBarController supplies the Liquid Glass surface and the expanded/inline transition.
    }

    private var detailText: String {
        guard let exercise else { return "Choose an exercise to get started" }
        if isCompact {
            return "\(exercise.numberOfSets) sets × \(exercise.reps) reps"
        }
        return "\(exercise.numberOfSets) sets × \(exercise.reps) reps · Increase Next: \(exercise.increaseLoadNextTime ? "Yes" : "No")"
    }
}

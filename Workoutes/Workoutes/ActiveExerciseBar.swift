import SwiftUI

struct ActiveExerciseBar: View {
    let exercise: ExerciseActivityAttributes.ContentState
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
                Text(exercise.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(isCompact
                     ? "\(exercise.numberOfSets) sets × \(exercise.reps) reps"
                     : "\(exercise.numberOfSets) sets × \(exercise.reps) reps · Increase Next: \(exercise.increaseLoadNextTime ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.body)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isUpdating)
            .accessibilityLabel("Stop active exercise")
        }
        .padding(.leading, isCompact ? 8 : 16)
        .padding(.trailing, 8)
        .padding(.vertical, isCompact ? 0 : 4)
        .accessibilityIdentifier("activeExerciseBar")
        // UITabBarController supplies the Liquid Glass surface and the expanded/inline transition.
    }
}

import SwiftUI

struct ResetCompletedExercisesButton: View {
    let exercises: [WorkoutExercise]

    var body: some View {
        Button {
            withAnimation {
                for exercise in exercises where exercise.isDone {
                    exercise.isDone = false
                }
            }
        } label: {
            Label("Uncheck All Exercises", systemImage: "arrow.counterclockwise")
        }
        .disabled(!exercises.contains(where: \.isDone))
        .accessibilityIdentifier("resetCompletedExercises")
        // The navigation toolbar supplies the native Liquid Glass surface.
    }
}

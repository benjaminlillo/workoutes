import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case summary, workouts, exercises, settings, activeExercise
}

struct ExerciseRevealRequest: Equatable {
    let id = UUID()
    let exerciseID: PersistentIdentifier
}

struct ExerciseRevealPosition: Equatable {
    let request: ExerciseRevealRequest
    let frame: CGRect
}

struct ExerciseRevealPositionKey: PreferenceKey {
    static let defaultValue: ExerciseRevealPosition? = nil

    static func reduce(value: inout ExerciseRevealPosition?, nextValue: () -> ExerciseRevealPosition?) {
        value = nextValue() ?? value
    }
}

@MainActor
@Observable
final class ExerciseNavigation {
    var selectedTab: AppTab = .summary
    var selectedTagIDs: Set<PersistentIdentifier> = []
    var revealRequest: ExerciseRevealRequest?

    func resolveActiveExerciseShortcut(_ exercise: WorkoutExercise?, previousTab: AppTab) {
        guard selectedTab == .activeExercise else { return }
        guard let exercise, !exercise.isDeleted else {
            selectedTab = previousTab == .activeExercise ? .exercises : previousTab
            return
        }
        reveal(exercise)
    }

    func reveal(_ exercise: WorkoutExercise) {
        guard !exercise.isDeleted else { return }
        if !selectedTagIDs.isEmpty,
           !exercise.tags.contains(where: { selectedTagIDs.contains($0.persistentModelID) }) {
            selectedTagIDs.removeAll()
        }
        // A fresh token also handles repeated taps on the same active exercise.
        revealRequest = ExerciseRevealRequest(exerciseID: exercise.persistentModelID)
        selectedTab = .exercises
    }
}

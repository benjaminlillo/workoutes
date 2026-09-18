import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ExerciseActivityController.self) private var exerciseActivity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var exercises: [WorkoutExercise]
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    
    private var activeExercise: WorkoutExercise? {
        exercises.first { !$0.isDeleted && !$0.isDone && exerciseActivity.isActive($0) }
    }

    var body: some View {
        TabView {
            Tab {
                WorkoutListView()
            } label: {
                Image(systemName: "list.bullet.clipboard")
                    .accessibilityLabel("Workouts")
            }
            Tab {
                ExerciseListView()
            } label: {
                Image(systemName: "dumbbell")
                    .accessibilityLabel("Exercises")
            }
            Tab {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Settings")
            }
        }
        .background {
            NativeExerciseAccessory(
                content: activeExercise?.activityContent,
                isUpdating: exerciseActivity.isUpdating,
                accentColor: ThemeColor(rawValue: accentColorRawValue)?.color ?? .mint
            ) {
                if let exercise = activeExercise {
                    exerciseActivity.toggle(exercise, context: modelContext)
                }
            }
        }
        .onChange(of: exercises.map { ExerciseSnapshot(content: $0.activityContent, isDone: $0.isDone) }, initial: true) {
            exerciseActivity.synchronize(exercises: exercises)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                exerciseActivity.restore()
                exerciseActivity.synchronize(exercises: exercises)
            }
        }
        .alert("Live Activity", isPresented: Binding(
            get: { exerciseActivity.errorMessage != nil },
            set: { if !$0 { exerciseActivity.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { exerciseActivity.errorMessage = nil }
        } message: {
            Text(exerciseActivity.errorMessage ?? "")
        }
    }
}

private struct ExerciseSnapshot: Equatable {
    let content: ExerciseActivityAttributes.ContentState
    let isDone: Bool
}

#Preview {
    ContentView()
        .environment(ExerciseBackgroundStore())
        .environment(ExerciseActivityController())
        .modelContainer(for: Workout.self, inMemory: true)
}

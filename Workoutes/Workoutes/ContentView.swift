import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ExerciseActivityController.self) private var exerciseActivity
    @Environment(\.scenePhase) private var scenePhase
    @Query private var exercises: [WorkoutExercise]
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    
    var body: some View {
        TabView {
            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "list.bullet.clipboard")
                }
            
            ExerciseListView()
                .tabItem {
                    Label("Exercises", systemImage: "dumbbell")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
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

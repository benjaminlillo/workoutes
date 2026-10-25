import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ExerciseActivityController.self) private var exerciseActivity
    @Environment(\.trainingController) private var training
    @Environment(\.scenePhase) private var scenePhase
    @Query private var exercises: [WorkoutExercise]
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.indigo.rawValue
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .metric
    @State private var motivationalPull = MotivationalPullState()
    @State var navigation = ExerciseNavigation()
    
    private var activeExercise: WorkoutExercise? {
        exercises.first { !$0.isDeleted && !$0.isDone && exerciseActivity.isActive($0) }
    }

    private var activeExerciseRole: TabRole {
        if #available(iOS 27.0, *) { .prominent } else { .search }
    }

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            Tab(value: AppTab.summary) {
                SummaryView(pull: $motivationalPull)
            } label: {
                Image(systemName: "house.fill").accessibilityLabel("Summary")
            }
            Tab(value: AppTab.workouts) {
                WorkoutListView()
            } label: {
                Image(systemName: "list.bullet.clipboard").accessibilityLabel("Workouts")
            }
            Tab(value: AppTab.exercises) {
                ExerciseListView(navigation: navigation)
            } label: {
                Image(systemName: "dumbbell").accessibilityLabel("Exercises")
            }
            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                Image(systemName: "gearshape").accessibilityLabel("Settings")
            }
            Tab(value: AppTab.activeExercise, role: activeExerciseRole) {
                // Selection is redirected after the native tab controller records the tap.
                EmptyView()
            } label: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .accessibilityLabel(activeExercise?.title ?? "No Active Exercise")
            }
            .disabled(activeExercise == nil)
        }
        .tabBarMinimizeBehavior(.never)
        .onChange(of: navigation.selectedTab) { previousTab, _ in
            navigation.resolveActiveExerciseShortcut(activeExercise, previousTab: previousTab)
        }
        .overlay {
            MotivationalPullOverlay(pull: motivationalPull)
        }
        .onChange(of: exercises.map { ExerciseSnapshot(content: $0.activityContent, isDone: $0.isDone) }, initial: true) {
            exerciseActivity.synchronize(exercises: exercises)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                training?.refresh()
                exerciseActivity.restore()
                exerciseActivity.synchronize(exercises: exercises)
            }
        }
        .onChange(of: accentColorRawValue) { exerciseActivity.synchronize(exercises: exercises) }
        .onChange(of: weightUnit) { exerciseActivity.synchronize(exercises: exercises) }
        .alert(training?.errorMessage != nil ? "Training" : "Exercise Session", isPresented: Binding(
            get: { exerciseActivity.errorMessage != nil || training?.errorMessage != nil },
            set: { if !$0 { exerciseActivity.errorMessage = nil; training?.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { exerciseActivity.errorMessage = nil; training?.errorMessage = nil }
        } message: {
            Text(training?.errorMessage ?? exerciseActivity.errorMessage ?? "")
        }
    }
}

private struct ExerciseSnapshot: Equatable {
    let content: ExerciseActivityAttributes.ContentState
    let isDone: Bool
}

#Preview {
    ContentView()
        .environment(ExerciseActivityController())
        .modelContainer(for: Workout.self, inMemory: true)
}

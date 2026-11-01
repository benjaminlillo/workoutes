import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ExerciseActivityController.self) private var exerciseActivity
    @Environment(\.trainingController) private var training
    @Environment(\.scenePhase) private var scenePhase
    @Query private var exercises: [WorkoutExercise]
    @Query private var tags: [Tag]
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.indigo.rawValue
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .metric
    @State private var motivationalPull = MotivationalPullState()
    @State var navigation = ExerciseNavigation()
    
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
        }
        .tabBarMinimizeBehavior(.never)
        .overlay {
            MotivationalPullOverlay(pull: motivationalPull)
        }
        .onChange(of: tags.map { TagPaletteSnapshot(id: $0.persistentModelID, paletteID: $0.paletteColorID, hex: $0.colorHex) }, initial: true) {
            TagColorSynchronization.apply(ThemeColor.resolve(accentColorRawValue), to: tags)
        }
        .onChange(of: exercises.map { ExerciseSnapshot(content: $0.activityContent, isDone: $0.isDone) }, initial: true) {
            exerciseActivity.synchronize(exercises: exercises)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                training?.refresh()
                exerciseActivity.restore()
            }
        }
        .onChange(of: accentColorRawValue) {
            withAnimation(.easeInOut(duration: 0.3)) {
                TagColorSynchronization.apply(ThemeColor.resolve(accentColorRawValue), to: tags)
            }
            exerciseActivity.synchronize(exercises: exercises)
        }
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

private struct TagPaletteSnapshot: Equatable {
    let id: PersistentIdentifier
    let paletteID: String?
    let hex: String
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

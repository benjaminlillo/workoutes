import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ExerciseActivityController.self) private var exerciseActivity
    @Environment(SessionController.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @Query private var exercises: [WorkoutExercise]
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .metric
    
    var body: some View {
        tabs
            .onChange(of: exerciseSnapshots, initial: true) {
                exerciseActivity.synchronize(exercises: exercises)
                session.reconcileActiveExercise()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    exerciseActivity.restore()
                    exerciseActivity.synchronize(exercises: exercises)
                }
                session.setSceneActive(phase == .active)
            }
            .onChange(of: accentColorRawValue) {
                exerciseActivity.synchronize(exercises: exercises)
                session.refreshPresentation()
            }
            .onChange(of: weightUnit) { exerciseActivity.synchronize(exercises: exercises) }
            .alert("Exercise", isPresented: exerciseAlertPresented) {
                Button("OK", role: .cancel) { exerciseActivity.errorMessage = nil }
            } message: { Text(exerciseActivity.errorMessage ?? "") }
            .alert("Session", isPresented: sessionAlertPresented) { sessionAlertActions } message: {
                Text(session.errorMessage ?? "Enable notifications in Settings to be alerted when a rest block finishes. The session will continue without them.")
            }
    }

    private var tabs: some View {
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
                SessionHistoryView()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .accessibilityLabel("History")
            }
            Tab {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Settings")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            sessionAccessory
        }
    }

    private var sessionAccessory: some View {
        NativeSessionAccessory(
            content: session.currentContent,
            isUpdating: session.isUpdating,
            onStart: { session.start() },
            onAdvance: { session.advance() }
        )
    }

    private var exerciseSnapshots: [ExerciseSnapshot] {
        exercises.map { ExerciseSnapshot(title: $0.title, isActive: $0.isActive, isDone: $0.isDone) }
    }

    private var exerciseAlertPresented: Binding<Bool> {
        Binding(
            get: { exerciseActivity.errorMessage != nil },
            set: { if !$0 { exerciseActivity.errorMessage = nil } }
        )
    }

    private var sessionAlertPresented: Binding<Bool> {
        Binding(
            get: { session.errorMessage != nil || session.notificationsUnavailable },
            set: {
                if !$0 {
                    session.errorMessage = nil
                    session.notificationsUnavailable = false
                }
            }
        )
    }

    @ViewBuilder private var sessionAlertActions: some View {
        if session.notificationsUnavailable {
            Button("Open Settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                session.notificationsUnavailable = false
            }
        }
        Button("OK", role: .cancel) {
            session.errorMessage = nil
            session.notificationsUnavailable = false
        }
    }
}

private struct ExerciseSnapshot: Equatable {
    let title: String
    let isActive: Bool
    let isDone: Bool
}

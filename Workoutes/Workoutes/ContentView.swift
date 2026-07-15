import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    
    var body: some View {
        TabView {
            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "list.bullet")
                }
            
            ExerciseListView()
                .tabItem {
                    Label("Exercises", systemImage: "dumbbell")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .overlay(alignment: .topTrailing) {
            Button("Test Live Activity") {
                let attrs = ExerciseAttributes(exerciseID: "test_isolated", title: "Direct Test", subtitle: "Isolated")
                let state = ExerciseAttributes.ContentState(isDone: false, weight: 100, reps: 5, sets: 5)
                if #available(iOS 16.2, *) {
                    do {
                        let activity = try Activity.request(attributes: attrs, content: ActivityContent(state: state, staleDate: nil))
                        print("Isolated Activity Started: \(activity.id)")
                    } catch {
                        print("Isolated Error: \(error)")
                    }
                }
            }
            .padding()
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Workout.self, inMemory: true)
}

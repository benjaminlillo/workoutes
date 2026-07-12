import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "list.bullet.clipboard")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Workout.self, inMemory: true)
}

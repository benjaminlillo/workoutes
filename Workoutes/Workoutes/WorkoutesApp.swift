import SwiftUI
import SwiftData

@main
struct WorkoutesApp: App {
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    @State private var exerciseBackground = ExerciseBackgroundStore()
    @State private var exerciseActivity = ExerciseActivityRuntime.shared.controller
    
    let sharedModelContainer = ExerciseActivityRuntime.shared.container

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(exerciseActivity)
                .environment(exerciseBackground)
                .tint(ThemeColor.resolve(accentColorRawValue).color)
                .onChange(of: accentColorRawValue, initial: true) {
                    let resolved = ThemeColor.resolve(accentColorRawValue).rawValue
                    if accentColorRawValue != resolved { accentColorRawValue = resolved }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

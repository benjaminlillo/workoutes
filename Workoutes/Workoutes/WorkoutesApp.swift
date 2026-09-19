import SwiftUI
import SwiftData

@main
struct WorkoutesApp: App {
    @UIApplicationDelegateAdaptor(WorkoutesAppDelegate.self) private var appDelegate
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    @State private var exerciseBackground = ExerciseBackgroundStore()
    @State private var exerciseActivity = ExerciseActivityRuntime.shared.controller
    @State private var session = ExerciseActivityRuntime.shared.sessionController
    
    let sharedModelContainer = ExerciseActivityRuntime.shared.container

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(exerciseActivity)
                .environment(session)
                .environment(exerciseBackground)
                .tint(ThemeColor(rawValue: accentColorRawValue)?.color ?? .mint)
        }
        .modelContainer(sharedModelContainer)
    }
}

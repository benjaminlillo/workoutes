import SwiftUI
import SwiftData

@main
struct WorkoutesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    @State private var exerciseBackground = ExerciseBackgroundStore()
    @State private var exerciseActivity = ExerciseActivityRuntime.shared.controller
    @State private var themeIcon = ThemeIconController()
    
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
                .task(id: scenePhase == .active ? ThemeColor.resolve(accentColorRawValue) : nil) {
                    guard scenePhase == .active else { return }
                    #if DEBUG
                    // Hosted unit tests change theme preferences; verify the system's icon UI separately.
                    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
                          NSClassFromString("XCTestCase") == nil else { return }
                    #endif
                    await themeIcon.update(for: ThemeColor.resolve(accentColorRawValue))
                }
                .alert("Icon Update Failed", isPresented: Binding(
                    get: { themeIcon.errorMessage != nil },
                    set: { if !$0 { themeIcon.errorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) { themeIcon.errorMessage = nil }
                } message: {
                    Text(themeIcon.errorMessage ?? "")
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

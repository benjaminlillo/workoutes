import SwiftUI
import SwiftData
import HealthKit
import UIKit

@main
struct WorkoutesApp: App {
    @UIApplicationDelegateAdaptor(TrainingPhoneDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    @State private var exerciseBackground = ExerciseBackgroundStore()
    @State private var exerciseActivity = ExerciseActivityRuntime.shared.controller
    @State private var themeIcon = ThemeIconController()
    @State private var training = PhoneTrainingController()
    
    let sharedModelContainer = ExerciseActivityRuntime.shared.container

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(exerciseActivity)
                .environment(exerciseBackground)
                .environment(\.trainingController, training)
                .task {
                    #if DEBUG
                    guard NSClassFromString("XCTestCase") == nil else { return }
                    #endif
                    training.attach(context: sharedModelContainer.mainContext, exerciseActivity: exerciseActivity)
                }
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

final class TrainingPhoneDelegate: NSObject, UIApplicationDelegate {
    private let healthStore = HKHealthStore()

    func applicationShouldRequestHealthAuthorization(_ application: UIApplication) {
        // HealthKit can forward a companion/extension authorization request to its host.
        healthStore.handleAuthorizationForExtension { _, error in
            if let error { NSLog("Health authorization could not be presented: %@", error.localizedDescription) }
        }
    }
}

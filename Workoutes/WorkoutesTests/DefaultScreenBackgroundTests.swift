import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class DefaultScreenBackgroundTests: XCTestCase {
    private func render(_ view: some View, scheme: ColorScheme = .light) throws -> Data {
        let renderer = ImageRenderer(content: view.frame(width: 398, height: 844).environment(\.colorScheme, scheme))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage?.pngData())
    }

    func testDefaultUsesExistingPaletteInBothColorSchemes() throws {
        for scheme in [ColorScheme.light, .dark] {
            XCTAssertEqual(try render(DefaultScreenBackground(), scheme: scheme),
                           try render(SoftBackgroundGradient(colors: ExerciseBackgroundStore.defaultGradientColors), scheme: scheme))
        }
    }

    func testDefaultIsIndependentOfSavedScreenCustomization() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let custom = ExerciseBackgroundStore(directory: directory)
        let before = try render(DefaultScreenBackground())
        try custom.saveGradient(colors: ["FF8800", "5599FF"])
        XCTAssertEqual(try render(DefaultScreenBackground()), before)
        XCTAssertEqual(try render(ScreenBackgroundView(background: custom)),
                       try render(SoftBackgroundGradient(colors: ["FF8800", "5599FF"])))
        XCTAssertNotEqual(try render(ScreenBackgroundView(background: custom)), before)
        XCTAssertEqual(custom.gradientColors, ["FF8800", "5599FF"])
    }

    func testAllAppScreensRenderWithDefaultOrCustomizedBackgrounds() async throws {
        let container = try ModelContainer(for: Workout.self, WorkoutExercise.self, Tag.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let exercise = WorkoutExercise(title: "Bench Press", subtitle: "Chest", details: "Controlled movement",
                                       numberOfSets: 3, reps: 10, increaseLoadNextTime: false, weight: 20)
        let workout = Workout(name: "Push Day", exercises: [exercise])
        context.insert(workout)
        try context.save()
        let controller = ExerciseActivityController(context: context, liveActivitiesEnabled: false)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let background = ExerciseBackgroundStore(directory: directory)
        try background.saveGradient(colors: ["FF8800", "FFDDAA"])
        let screens: [(String, AnyView)] = [
            ("summary", AnyView(SummaryView())),
            ("workouts", AnyView(WorkoutListView())),
            ("settings", AnyView(SettingsView())),
            ("import", AnyView(NavigationStack { ImportDataView() })),
            ("create-workout", AnyView(CreateWorkoutSheet())),
            ("create-exercise", AnyView(CreateGlobalExerciseSheet())),
            ("add-exercise", AnyView(CreateExerciseSheet(workout: workout))),
            ("edit-exercise", AnyView(EditExerciseSheet(exercise: exercise))),
            ("tag", AnyView(ManageTagSheet())),
            ("weight", AnyView(ExerciseWeightSheet(exercise: exercise, unit: .metric))),
            ("sets", AnyView(ExerciseCountSheet(exercise: exercise, metric: .sets))),
            ("reps", AnyView(ExerciseCountSheet(exercise: exercise, metric: .repetitions))),
            ("background-editor", AnyView(BackgroundCustomizationSheet(background: background, title: "Exercises Background"))),
            ("custom-exercises", AnyView(ExerciseListView())),
            ("workout-detail", AnyView(NavigationStack { WorkoutDetailView(workout: workout) }))
        ]
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        for (name, view) in screens {
            let root = UIHostingController(rootView: view.environment(controller).environment(background).modelContainer(container))
            let window = UIWindow(windowScene: scene)
            window.rootViewController = root
            window.overrideUserInterfaceStyle = .light
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            try await Task.sleep(for: .milliseconds(200))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            XCTAssertGreaterThan(image.size.height, 300)
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-background-\(name).png"))
        }
        XCTAssertEqual(background.gradientColors, ["FF8800", "FFDDAA"])
    }
}

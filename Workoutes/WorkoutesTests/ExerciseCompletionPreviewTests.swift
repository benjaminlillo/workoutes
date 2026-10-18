import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class ExerciseCompletionPreviewTests: XCTestCase {
    private func container(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self])
        let config = url.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func exercise() -> WorkoutExercise {
        let item = WorkoutExercise(title: "Press de banca", subtitle: "Pecho · Fuerza", details: "Bajar con control",
                                   numberOfSets: 4, reps: 8, increaseLoadNextTime: true, weight: 60)
        item.tags = [Tag(name: "Pecho", colorHex: "FF8800", iconName: "chest"),
                     Tag(name: "Fuerza", colorHex: "5599FF")]
        return item
    }

    func testCompletionCapturesValuesOnceAndSurvivesCatalogChangesAndDeletion() async throws {
        let store = try container()
        let context = store.mainContext
        let item = exercise()
        context.insert(item)
        try context.save()
        let expected = ExerciseCompletionSnapshot(exercise: item)
        var now = Date.now
        let controller = ExerciseActivityController(context: context, now: { now }, liveActivitiesEnabled: false)
        controller.advanceState(item, context: context)
        await controller.waitForPendingUpdates()
        now = now.addingTimeInterval(11)
        controller.advanceState(item, context: context)
        await controller.waitForPendingUpdates()

        let entry = try XCTUnwrap(try context.fetch(FetchDescriptor<ExerciseCompletion>()).first)
        XCTAssertEqual(entry.snapshot, expected)
        item.title = "Edited"; item.subtitle = "New subtitle"; item.details = "New notes"
        item.weight = 90; item.reps = 12; item.numberOfSets = 2; item.increaseLoadNextTime = false
        item.tags.first?.colorHex = "00FF00"; item.tags.first?.iconName = "back"
        controller.advanceState(item, context: context)
        XCTAssertFalse(item.isDone)
        XCTAssertEqual(entry.snapshot, expected)

        for tag in item.tags { context.delete(tag) }
        context.delete(item)
        try context.save()
        let reloaded = try XCTUnwrap(try ModelContext(store).fetch(FetchDescriptor<ExerciseCompletion>()).first)
        XCTAssertNil(reloaded.exercise)
        XCTAssertEqual(reloaded.snapshot, expected)
    }

    func testSnapshotSurvivesDiskReopenAndLegacyEntriesRemainWithoutOne() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("catalog.store")
        let expected = ExerciseCompletionSnapshot(exercise: exercise())
        do {
            let store = try container(url: url)
            let item = exercise()
            store.mainContext.insert(item)
            store.mainContext.insert(ExerciseCompletion(id: "saved", completedAt: .now, exercise: item, snapshot: expected))
            store.mainContext.insert(ExerciseCompletion(id: "legacy", completedAt: .now, exercise: item))
            try store.mainContext.save()
        }
        let reopened = try container(url: url)
        let entries = try reopened.mainContext.fetch(FetchDescriptor<ExerciseCompletion>())
        XCTAssertEqual(entries.first { $0.id == "saved" }?.snapshot, expected)
        XCTAssertNil(entries.first { $0.id == "legacy" }?.snapshot)
        XCTAssertNil(entries.first { $0.id == "legacy" }?.snapshotData)
    }

    func testBackupPreservesSnapshotsWithoutCatalogReferencesAndDoesNotOverwriteHistory() throws {
        let source = try container()
        let item = exercise()
        source.mainContext.insert(item)
        let expected = ExerciseCompletionSnapshot(exercise: item)
        let entry = ExerciseCompletion(id: "saved", completedAt: .now, exercise: item, snapshot: expected)
        source.mainContext.insert(entry)
        source.mainContext.insert(ExerciseCompletion(id: "legacy", completedAt: .now, exercise: nil))
        try source.mainContext.save()
        source.mainContext.delete(item)
        try source.mainContext.save()

        let backup = try DataBackup.export(from: source.mainContext, includeHistory: true)
        let target = try container()
        try DataBackup.importData(backup, into: target.mainContext)
        try DataBackup.importData(backup, into: target.mainContext)
        var entries = try target.mainContext.fetch(FetchDescriptor<ExerciseCompletion>())
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first { $0.id == "saved" }?.snapshot, expected)
        XCTAssertNil(entries.first { $0.id == "saved" }?.exercise)
        XCTAssertNil(entries.first { $0.id == "legacy" }?.snapshot)

        var altered = expected
        altered.weight = 500
        entry.snapshotData = try JSONEncoder().encode(altered)
        try DataBackup.importData(DataBackup.export(from: source.mainContext, includeHistory: true), into: target.mainContext)
        entries = try target.mainContext.fetch(FetchDescriptor<ExerciseCompletion>())
        XCTAssertEqual(entries.first { $0.id == "saved" }?.snapshot, expected)
    }

    func testInvalidSnapshotImportDoesNotPartiallyChangeCatalog() throws {
        let store = try container()
        var invalid = ExerciseCompletionSnapshot(exercise: exercise())
        invalid.weight = -1
        let data = ExportDataDTO(workouts: [.init(id: "new", name: "Must not be inserted")], exercises: [], tags: [],
                                 history: [.init(id: "bad", completedAt: .now, exerciseID: nil, snapshot: invalid)])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        XCTAssertThrowsError(try DataBackup.importData(encoder.encode(data), into: store.mainContext))
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<Workout>()), 0)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
    }

    func testWatchCompletionUsesTheSelectedSnapshotRatherThanEditedCatalogValues() throws {
        let store = try container()
        let item = exercise()
        item.numberOfSets = 1
        store.mainContext.insert(item)
        try store.mainContext.save()
        let expected = ExerciseCompletionSnapshot(exercise: item)
        let start = Date.now
        var run = try TrainingRun(plan: .init(blocks: [.init(kind: .exercise, seconds: 0)]), at: start)
        try run.select(TrainingExercise(id: try XCTUnwrap(item.stableID), name: item.title, weightKilograms: item.weight,
                                        repetitions: item.reps, sets: 1, usesPounds: false, historySnapshot: expected), at: start)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = PhoneTrainingController(store: TrainingStore(url: directory.appendingPathComponent("training.json")), activate: false)
        controller.attach(context: store.mainContext,
                          exerciseActivity: ExerciseActivityController(context: store.mainContext, liveActivitiesEnabled: false))
        item.title = "Changed while the watch was running"; item.weight = 100
        item.tags.first?.colorHex = "00FF00"
        try run.advance(at: start.addingTimeInterval(30))
        controller.receive(.init(kind: .snapshot, run: run))
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertNil(controller.errorMessage)
        let entries = try store.mainContext.fetch(FetchDescriptor<ExerciseCompletion>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.snapshot, expected)
    }

    func testOldWatchExercisePayloadStillDecodesWithoutInventingSnapshot() throws {
        let data = Data("""
        {"id":"old","name":"Bench","weightKilograms":60,"repetitions":8,"sets":3,"usesPounds":false}
        """.utf8)
        let payload = try JSONDecoder().decode(TrainingExercise.self, from: data)
        XCTAssertTrue(payload.isValid)
        XCTAssertNil(payload.historySnapshot)
    }

    func testPreviewsRenderInLightDarkAndLargeTextWithoutChangingModels() throws {
        let store = try container()
        let item = exercise()
        store.mainContext.insert(item)
        try store.mainContext.save()
        let expected = ExerciseCompletionSnapshot(exercise: item)
        let before = try DataBackup.export(from: store.mainContext, includeHistory: true)
        for (name, snapshot, scheme, size) in [
            ("saved", Optional(expected), ColorScheme.light, DynamicTypeSize.large),
            ("dark", Optional(expected), .dark, .large),
            ("large-text", Optional(expected), .light, .accessibility3),
            ("legacy", nil, .light, .large)
        ] {
            let renderer = ImageRenderer(content: ExerciseCompletionPreview(completedAt: .now, snapshot: snapshot)
                .frame(width: 360).background(Color(uiColor: .systemBackground))
                .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertGreaterThan(image.size.height, 100)
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-completion-preview-\(name).png"))
        }
        XCTAssertEqual(try DataBackup.export(from: store.mainContext, includeHistory: true), before)
    }

    func testBlockPresentsNativePopoverForSavedAndLegacyHistory() async throws {
        let store = try container()
        let item = exercise()
        store.mainContext.insert(item)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        for (name, saved) in [("saved", true), ("legacy", false)] {
            let entry = ExerciseCompletion(id: name, completedAt: .now, exercise: item,
                                           snapshot: saved ? ExerciseCompletionSnapshot(exercise: item) : nil)
            store.mainContext.insert(entry)
            try store.mainContext.save()
            let root = UIHostingController(rootView: WeeklyExerciseBlock(completion: entry, height: 100, isPreviewPresented: true)
                .frame(width: 40).padding(150).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DefaultScreenBackground()))
            let window = UIWindow(windowScene: scene)
            window.rootViewController = root
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            try await Task.sleep(for: .milliseconds(600))
            let presented = try XCTUnwrap(root.presentedViewController)
            XCTAssertNotNil(presented.popoverPresentationController, "The preview must stay a popover on iPhone")
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-weekly-popover-\(name).png"))
            for _ in 0..<30 where presented.isBeingPresented {
                try await Task.sleep(for: .milliseconds(100))
            }
            await withCheckedContinuation { continuation in
                presented.dismiss(animated: false) { continuation.resume() }
            }
            XCTAssertNil(root.presentedViewController)
        }
    }
}

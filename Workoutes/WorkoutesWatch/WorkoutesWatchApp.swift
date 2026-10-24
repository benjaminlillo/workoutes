import SwiftUI
import HealthKit
import WatchKit

@main
struct WorkoutesWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @WKApplicationDelegateAdaptor(TrainingWatchDelegate.self) private var delegate
    @State private var controller = WatchTrainingController.shared
    var body: some Scene {
        WindowGroup {
            WatchTrainingView(controller: controller)
                .task { await controller.restore() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { controller.refreshConnection() }
                }
        }
    }
}

final class TrainingWatchDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        WatchTrainingController.shared.handleLaunch()
    }
    func handleActiveWorkoutRecovery() {
        Task { await WatchTrainingController.shared.restore() }
    }
}

struct WatchTrainingView: View {
    @Bindable var controller: WatchTrainingController
    @State private var finishing = false
    @State private var effort = 5
    var body: some View {
        Group {
            if let run = controller.run, run.isActive {
                WatchActiveTrainingView(run: run, isBusy: controller.isBusy,
                                        onAction: { controller.local($0) }, onFinish: {
                    if run.plan.asksForEffortRating { finishing = true }
                    else { controller.local(.finish) }
                })
                    .id(run.id)
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 12) {
                            Image(systemName: "dumbbell.fill").font(.largeTitle)
                            if let run = controller.run {
                                Text("Training Complete").font(.headline)
                                Text(TrainingClock.label(run.elapsed(at: run.endedAt ?? .now)))
                                if let calories = run.metrics.activeCalories { Text("\(Int(calories)) active kcal") }
                                if let recovery = run.metrics.recoveryOneMinute { Text("Recovery: \(Int(recovery)) bpm").font(.caption) }
                                if controller.isBusy { ProgressView("Saving to Health…") }
                                if let error = run.healthSaveError {
                                    Text(error).font(.caption)
                                    Button("Retry Health Save") { controller.local(.retrySave) }.disabled(controller.isBusy)
                                    if run.healthSaveSkipped != true {
                                        Button("Keep Local Record and Continue") { controller.local(.keepLocalRecord) }.disabled(controller.isBusy)
                                    }
                                } else if run.healthWorkoutID != nil {
                                    Label("Saved to Health", systemImage: "checkmark.circle").font(.caption)
                                }
                            }
                            Text(controller.archive.plan.name).font(.headline)
                            #if targetEnvironment(simulator)
                            Text("Simulator Preview\nNo Health recording").font(.caption).foregroundStyle(.orange)
                            #endif
                            Text("\(controller.archive.plan.exerciseCount) exercise blocks").font(.caption)
                            Button("Start Training") { controller.startFromWatch() }
                                .disabled(!controller.canStart)
                            Text("Configure your structure and choose exercises on iPhone.").font(.caption).foregroundStyle(.secondary)
                        }.multilineTextAlignment(.center)
                    }
                    .navigationTitle("Workoutes")
                }
            }
        }
        .sheet(isPresented: $finishing) {
            ScrollView {
                Text("How hard was it?").font(.headline)
                Picker("Effort", selection: $effort) {
                    ForEach(1...10, id: \.self) { Text("\($0) / 10").tag($0) }
                }
                Button(controller.run?.isSimulatorPreview == true ? "Finish Preview" : "Finish and Save") {
                    finishing = false; controller.local(.finish, effort: effort)
                }
                Button("Skip Rating") { finishing = false; controller.local(.finish) }
                Button("Cancel", role: .cancel) { finishing = false }
            }
        }
        .alert("Training", isPresented: Binding(get: { controller.errorMessage != nil }, set: { if !$0 { controller.errorMessage = nil } })) {
            Button("OK", role: .cancel) { controller.errorMessage = nil }
        } message: { Text(controller.errorMessage ?? "") }
    }
}

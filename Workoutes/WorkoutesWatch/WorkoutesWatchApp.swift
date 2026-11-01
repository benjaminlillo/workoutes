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
                .onChange(of: scenePhase, initial: true) { _, phase in
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
    @State private var recoveringHealthSave = false
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
                startScreen
            }
        }
        .sheet(isPresented: $recoveringHealthSave) {
            ScrollView {
                if let error = controller.run?.healthSaveError {
                    Text(error).font(.caption)
                }
                Button("Retry Health Save") {
                    recoveringHealthSave = false
                    controller.local(.retrySave)
                }
                Button("Keep Local Record and Continue") {
                    recoveringHealthSave = false
                    controller.local(.keepLocalRecord)
                }
                Button("Cancel", role: .cancel) { recoveringHealthSave = false }
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

    private var startScreen: some View {
        VStack(spacing: 24) {
            Text("Workoutes")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Button {
                if controller.run?.healthSaveError != nil, controller.run?.healthSaveSkipped != true {
                    recoveringHealthSave = true
                } else {
                    controller.startFromWatch()
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color(red: 0.03, green: 0.22, blue: 0.09))
                    .offset(x: 2)
                    .frame(width: 96, height: 96)
                    .background {
                        Circle().fill(LinearGradient(
                            colors: [Color(red: 0.62, green: 0.96, blue: 0.23),
                                     Color(red: 0.17, green: 0.77, blue: 0.31)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(controller.isBusy)
            .opacity(controller.isBusy ? 0.45 : 1)
            .accessibilityLabel("Start Training")
            .accessibilityIdentifier("watchStartTraining")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }
}

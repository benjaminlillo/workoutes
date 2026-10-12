import SwiftUI

private struct TrainingControllerKey: EnvironmentKey {
    static let defaultValue: PhoneTrainingController? = nil
}
extension EnvironmentValues {
    var trainingController: PhoneTrainingController? {
        get { self[TrainingControllerKey.self] }
        set { self[TrainingControllerKey.self] = newValue }
    }
}

struct TrainingEntryView: View {
    @Bindable var controller: PhoneTrainingController
    var body: some View {
        NavigationLink {
            TrainingView(controller: controller)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "applewatch").font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(controller.hasActiveSession ? "Training in Progress" : "Train with Apple Watch").font(.headline)
                    Text(controller.hasActiveSession ? controller.run?.phaseTitle ?? "" : "Choose exercises as you go")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(20)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
            .subtleCardBorder(cornerRadius: 24)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("watchTrainingEntry")
    }
}

struct TrainingView: View {
    @Bindable var controller: PhoneTrainingController
    @State private var editingPlan = false
    @State private var finishing = false

    var body: some View {
        List {
            if let run = controller.run, run.isActive {
                Section("Current Training") {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        TrainingSessionSummary(run: run, date: timeline.date)
                    }
                    if !controller.isConnected {
                        Label("Open Workoutes on your watch to reconnect. The session continues there.", systemImage: "applewatch.slash")
                            .foregroundStyle(.secondary)
                    }
                    Button(run.pausedAt == nil ? "Pause Training" : "Resume Training") { controller.pause() }
                        .disabled(!controller.isConnected)
                    if run.canAdvance {
                        Button(run.progress.stage == .series ? "Finish Series" : "Skip Rest") { controller.advance() }
                            .disabled(!controller.isConnected)
                    }
                    if run.undo != nil {
                        Button("Undo Last Transition") { controller.undo() }
                            .disabled(!controller.isConnected || run.pausedAt != nil)
                    }
                    Button("Finish Training") { finishing = true }
                        .disabled(!controller.isConnected)
                }
            } else {
                Section {
                    Text(controller.plan.name).font(.headline)
                    #if targetEnvironment(simulator)
                    Label("Simulator Preview · No Health recording", systemImage: "testtube.2")
                        .font(.caption).foregroundStyle(.orange)
                    #endif
                    Text("\(controller.plan.exerciseCount) exercise blocks · choose exercises as you train")
                        .foregroundStyle(.secondary)
                    Button(controller.isStarting ? "Starting on Apple Watch…" : "Start Training on Apple Watch") {
                        Task { await controller.start() }
                    }
                    .disabled(controller.isStarting)
                    .accessibilityIdentifier("startWatchTraining")
                }
            }
            if let run = controller.run, !run.isActive, run.healthSaveError != nil {
                Section("Health Save") {
                    Text(run.healthSaveError ?? "")
                    Button("Retry on Apple Watch") { controller.retrySave() }.disabled(!controller.isConnected)
                    if run.healthSaveSkipped != true {
                        Text("If Health cannot be saved, you can keep this record in Workoutes and start another session.").font(.caption)
                        Button("Keep Local Record and Continue") { controller.keepLocalRecord() }.disabled(!controller.isConnected)
                    }
                }
            }
            Section("Structure") {
                Button("Edit Training Structure") { editingPlan = true }
                    .disabled(controller.hasActiveSession || controller.isStarting)
                ForEach(Array(controller.plan.blocks.enumerated()), id: \.element.id) { index, block in
                    Label {
                        VStack(alignment: .leading) {
                            Text(block.kind == .exercise ? "Exercise Block" : "Rest Block")
                            Text(block.kind == .exercise
                                 ? "Open duration · \(TrainingClock.label(TimeInterval(block.seconds))) between series"
                                 : "\(TrainingClock.label(TimeInterval(block.seconds))) · automatic advance")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: block.kind == .exercise ? "dumbbell" : "timer") }
                    .accessibilityIdentifier("trainingBlock.\(index)")
                }
            }
            Section("Training History") {
                if controller.history.isEmpty { Text("Completed sessions will appear here.").foregroundStyle(.secondary) }
                ForEach(controller.history) { run in
                    NavigationLink {
                        List {
                            TrainingSessionSummary(run: run, date: run.endedAt ?? .now)
                            ForEach(run.progress.results) { result in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.exercise.name).font(.headline)
                                    Text("\(result.exercise.weightLabel) · \(result.exercise.repetitions) reps · \(result.sets.count)/\(result.exercise.sets) series")
                                    Text(result.isComplete ? "Completed" : "Incomplete").foregroundStyle(.secondary)
                                }
                            }
                            if !run.metrics.zones.isEmpty {
                                Section("Heart Rate Zones") {
                                    ForEach(run.metrics.zones) { zone in
                                        LabeledContent("Zone \(zone.id + 1)", value: TrainingClock.label(zone.seconds))
                                    }
                                }
                            }
                            if let effort = run.effort { LabeledContent("Effort", value: "\(effort)/10") }
                            Text(run.healthWorkoutID != nil ? "Saved to Apple Health" : (run.healthSaveSkipped == true ? "Kept in Workoutes only" : "Health save pending"))
                                .foregroundStyle(.secondary)
                            if let error = run.healthSaveError { Text(error).font(.caption).foregroundStyle(.secondary) }
                        }
                        .navigationTitle("Training Summary")
                    } label: {
                        VStack(alignment: .leading) {
                            Text(run.plan.name)
                            if run.isSimulatorPreview == true {
                                Text("Simulator Preview").font(.caption).foregroundStyle(.orange)
                            }
                            Text(run.startedAt, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Training")
        .transparentNavigationChrome()
        .defaultScreenBackground()
        .toolbar { Button { controller.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") } }
        .sheet(isPresented: $editingPlan) { TrainingPlanEditor(plan: controller.plan, save: controller.savePlan) }
        .sheet(isPresented: $finishing) {
            TrainingFinishSheet(isSimulatorPreview: controller.run?.isSimulatorPreview == true) { effort in
                controller.finish(effort: effort); finishing = false
            }
        }
    }
}

struct TrainingSessionSummary: View {
    let run: TrainingRun
    let date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if run.isSimulatorPreview == true {
                Label("Simulator Preview · No Health recording", systemImage: "testtube.2")
                    .font(.caption).foregroundStyle(.orange)
            }
            Text(run.phaseTitle).font(.headline)
            if let exercise = run.currentResult?.exercise {
                Text(exercise.name).font(.title3.bold())
                Text("\(exercise.weightLabel) · \(exercise.repetitions) reps · \(exercise.sets) series")
            } else if run.progress.stage == .choosingExercise {
                Text("Select the active exercise from your exercise list.").foregroundStyle(.secondary)
            }
            if run.isActive {
                Text("Exercise \(run.exerciseNumber) of \(run.plan.exerciseCount)").font(.caption).foregroundStyle(.secondary)
                Text(TrainingClock.label(run.remaining(at: date) ?? run.phaseElapsed(at: date)))
                    .font(.largeTitle.monospacedDigit())
            }
            LabeledContent("Duration", value: TrainingClock.label(run.elapsed(at: date)))
            if run.pausedAt != nil { Label("Paused", systemImage: "pause.fill") }
            if let hr = run.metrics.heartRate, run.isActive { LabeledContent("Heart Rate", value: "\(Int(hr)) bpm") }
            if let hr = run.metrics.averageHeartRate { LabeledContent("Average Heart Rate", value: "\(Int(hr)) bpm") }
            if let hr = run.metrics.maximumHeartRate { LabeledContent("Maximum Heart Rate", value: "\(Int(hr)) bpm") }
            if let calories = run.metrics.activeCalories { LabeledContent("Active Calories", value: "\(Int(calories)) kcal") }
            if let calories = run.metrics.totalCalories { LabeledContent("Total Calories", value: "\(Int(calories)) kcal") }
            if let recovery = run.metrics.recoveryOneMinute { LabeledContent("Heart Rate Recovery (1 min)", value: "\(Int(recovery)) bpm") }
        }
    }
}

struct TrainingPlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var plan: TrainingPlan
    let save: (TrainingPlan) throws -> Void
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section { TextField("Name", text: $plan.name) }
                Section {
                    ForEach($plan.blocks) { $block in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(block.kind == .exercise ? "Exercise Block" : "Rest Block",
                                  systemImage: block.kind == .exercise ? "dumbbell" : "timer")
                            Stepper(value: $block.seconds, in: (block.kind == .exercise ? 0 : 15)...3_600, step: 15) {
                                Text("\(block.kind == .exercise ? "Rest between series" : "Duration"): \(TrainingClock.label(TimeInterval(block.seconds)))")
                            }
                            Text(block.kind == .exercise ? "Choose the exercise during training. Its series, repetitions and weight come from your catalog."
                                 : "Automatically moves to the next block when the timer ends.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { plan.blocks.remove(atOffsets: $0) }
                    .onMove { plan.blocks.move(fromOffsets: $0, toOffset: $1) }
                } header: { Text("Blocks") } footer: { Text("An exercise runs for as long as you need. Double-tap the watch display to finish each series.") }
                Section {
                    Button("Add Exercise Block") { plan.blocks.append(.init(kind: .exercise, seconds: 120)) }
                    Button("Add Rest Block") { plan.blocks.append(.init(kind: .rest, seconds: 300)) }
                }.disabled(plan.blocks.count >= 40)
            }
            .navigationTitle("Training Structure")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try save(plan); dismiss() } catch { self.error = error.localizedDescription }
                    }.disabled(!plan.isValid)
                }
            }
            .alert("Save Failed", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}

struct TrainingFinishSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var effort = 5
    var isSimulatorPreview = false
    let finish: (Int?) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("How Hard Was Your Training?") {
                    Stepper("Effort: \(effort)/10", value: $effort, in: 1...10)
                    Text(isSimulatorPreview ? "Preview results stay in Workoutes. Nothing is saved to Apple Health."
                         : "This rating contributes to Apple's training load.").font(.caption).foregroundStyle(.secondary)
                }
                Button(isSimulatorPreview ? "Finish Preview" : "Finish and Save to Health") { finish(effort) }
                Button("Finish Without an Effort Rating") { finish(nil) }
            }
            .navigationTitle("Finish Training")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

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
            .subtleCardShadow()
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
                    .subtleFormRowShadow(.first)
                    if !controller.isConnected {
                        Label("Watch Controls Unavailable", systemImage: "applewatch")
                            .foregroundStyle(.secondary)
                            .subtleFormRowShadow(.middle)
                        if let lastSync = controller.lastSyncedAt {
                            LabeledContent("Last Sync") { Text(lastSync, style: .relative) }
                                .foregroundStyle(.secondary)
                                .subtleFormRowShadow(.middle)
                        }
                    }
                    Button(run.pausedAt == nil ? "Pause Training" : "Resume Training") { controller.pause() }
                        .disabled(!controller.isConnected)
                        .subtleFormRowShadow(.middle)
                    if run.canAdvance {
                        Button(run.progress.stage == .series ? "Finish Series" : "Skip Rest") { controller.advance() }
                            .disabled(!controller.isConnected)
                            .subtleFormRowShadow(.middle)
                    }
                    if run.undo != nil {
                        Button("Undo Last Transition") { controller.undo() }
                            .disabled(!controller.isConnected || run.pausedAt != nil)
                            .subtleFormRowShadow(.middle)
                    }
                    if run.queuedExercise != nil {
                        Button("Remove Queued Exercise") { controller.clearQueuedExercise() }
                            .disabled(!controller.isConnected || run.pausedAt != nil)
                            .subtleFormRowShadow(.middle)
                    }
                    Button("Finish Training") {
                        if run.plan.asksForEffortRating { finishing = true }
                        else { controller.finish(effort: nil) }
                    }
                        .disabled(!controller.isConnected)
                        .subtleFormRowShadow(.last)
                }
            } else {
                Section {
                    Text(controller.plan.name).font(.headline)
                        .subtleFormRowShadow(.first)
                    #if targetEnvironment(simulator)
                    Label("Simulator Preview · No Health recording", systemImage: "testtube.2")
                        .font(.caption).foregroundStyle(.orange)
                        .subtleFormRowShadow(.middle)
                    #endif
                    Text("\(controller.plan.exerciseCount) exercise blocks · choose exercises as you train")
                        .foregroundStyle(.secondary)
                        .subtleFormRowShadow(.middle)
                    Button(controller.isStarting ? "Starting on Apple Watch…" : "Start Training on Apple Watch") {
                        Task { await controller.start() }
                    }
                    .disabled(controller.isStarting)
                    .accessibilityIdentifier("startWatchTraining")
                    .subtleFormRowShadow(.last)
                }
            }
            if let run = controller.run, !run.isActive, run.healthSaveError != nil {
                Section("Health Save") {
                    Text(run.healthSaveError ?? "")
                        .subtleFormRowShadow(.first)
                    Button("Retry on Apple Watch") { controller.retrySave() }
                        .disabled(!controller.isConnected)
                        .subtleFormRowShadow(run.healthSaveSkipped == true ? .last : .middle)
                    if run.healthSaveSkipped != true {
                        Text("If Health cannot be saved, you can keep this record in Workoutes and start another session.").font(.caption)
                            .subtleFormRowShadow(.middle)
                        Button("Keep Local Record and Continue") { controller.keepLocalRecord() }
                            .disabled(!controller.isConnected)
                            .subtleFormRowShadow(.last)
                    }
                }
            }
            Section("Structure") {
                Button("Edit Training Structure") { editingPlan = true }
                    .disabled(controller.hasActiveSession || controller.isStarting)
                    .subtleFormRowShadow(controller.plan.blocks.isEmpty ? .single : .first)
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
                    .subtleFormRowShadow(.row(at: index + 1, count: controller.plan.blocks.count + 1))
                }
            }
            Section("Training History") {
                if controller.history.isEmpty {
                    Text("Completed sessions will appear here.").foregroundStyle(.secondary)
                        .subtleFormRowShadow()
                }
                ForEach(Array(controller.history.enumerated()), id: \.element.id) { index, run in
                    NavigationLink {
                        TrainingHistoryDetail(run: run)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(run.plan.name)
                            if run.isSimulatorPreview == true {
                                Text("Simulator Preview").font(.caption).foregroundStyle(.orange)
                            }
                            Text(run.startedAt, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .subtleFormRowShadow(.row(at: index, count: controller.history.count))
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

private struct TrainingHistoryDetail: View {
    let run: TrainingRun

    var body: some View {
        List {
            Section {
                TrainingSessionSummary(run: run, date: run.endedAt ?? .now)
                    .subtleFormRowShadow(run.progress.results.isEmpty ? .single : .first)
                ForEach(Array(run.progress.results.enumerated()), id: \.element.id) { index, result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.exercise.name).font(.headline)
                        Text("\(result.exercise.weightLabel) · \(result.exercise.repetitions) reps · \(result.sets.count)/\(result.exercise.sets) series")
                        Text(result.isComplete ? "Completed" : "Incomplete").foregroundStyle(.secondary)
                    }
                    .subtleFormRowShadow(.row(at: index + 1, count: run.progress.results.count + 1))
                }
            }
            if !run.metrics.zones.isEmpty {
                Section("Heart Rate Zones") {
                    ForEach(Array(run.metrics.zones.enumerated()), id: \.element.id) { index, zone in
                        LabeledContent("Zone \(zone.id + 1)", value: TrainingClock.label(zone.seconds))
                            .subtleFormRowShadow(.row(at: index, count: run.metrics.zones.count))
                    }
                }
            }
            Section {
                if let effort = run.effort {
                    LabeledContent("Effort", value: "\(effort)/10")
                        .subtleFormRowShadow(.first)
                }
                Text(run.healthWorkoutID != nil ? "Saved to Apple Health" : (run.healthSaveSkipped == true ? "Kept in Workoutes only" : "Health save pending"))
                    .foregroundStyle(.secondary)
                    .subtleFormRowShadow(.row(at: run.effort == nil ? 0 : 1,
                                              count: 1 + (run.effort == nil ? 0 : 1) + (run.healthSaveError == nil ? 0 : 1)))
                if let error = run.healthSaveError {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                        .subtleFormRowShadow(.last)
                }
            }
        }
        .navigationTitle("Training Summary")
        .transparentNavigationChrome()
        .defaultScreenBackground()
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
            if let queued = run.queuedExercise, let number = run.queuedExerciseNumber {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Queued · Exercise \(number)", systemImage: "text.line.first.and.arrowtriangle.forward")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(queued.name).font(.headline)
                    Text("\(queued.weightLabel) · \(queued.repetitions) reps · \(queued.sets) series").font(.subheadline)
                }
                .accessibilityIdentifier("trainingQueuedExercise")
            }
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
                Section {
                    TextField("Name", text: $plan.name)
                        .subtleFormRowShadow()
                }
                Section {
                    Toggle("Ask for Effort Rating", isOn: $plan.asksForEffortRating)
                        .accessibilityIdentifier("trainingAskForEffortRating")
                        .subtleFormRowShadow()
                } header: {
                    Text("End of Training")
                } footer: {
                    Text("When disabled, finishing training skips the effort question and saves no effort rating in Workoutes or Apple Health. Applies to new sessions.")
                }
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
                        .subtleFormRowShadow(.row(at: plan.blocks.firstIndex(where: { $0.id == block.id }) ?? 0,
                                                  count: plan.blocks.count))
                    }
                    .onDelete { plan.blocks.remove(atOffsets: $0) }
                    .onMove { plan.blocks.move(fromOffsets: $0, toOffset: $1) }
                } header: { Text("Blocks") } footer: { Text("An exercise runs for as long as you need. Double-tap the watch display to finish each series.") }
                Section {
                    Button("Add Exercise Block") { plan.blocks.append(.init(kind: .exercise, seconds: 120)) }
                        .subtleFormRowShadow(.first)
                    Button("Add Rest Block") { plan.blocks.append(.init(kind: .rest, seconds: 300)) }
                        .subtleFormRowShadow(.last)
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
                        .subtleFormRowShadow(.first)
                    Text(isSimulatorPreview ? "Preview results stay in Workoutes. Nothing is saved to Apple Health."
                         : "This rating contributes to Apple's training load.").font(.caption).foregroundStyle(.secondary)
                        .subtleFormRowShadow(.last)
                }
                Button(isSimulatorPreview ? "Finish Preview" : "Finish and Save to Health") { finish(effort) }
                    .subtleFormRowShadow(.first)
                Button("Finish Without an Effort Rating") { finish(nil) }
                    .subtleFormRowShadow(.last)
            }
            .navigationTitle("Finish Training")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

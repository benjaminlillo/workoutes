import SwiftUI

struct WatchActiveTrainingView: View {
    let run: TrainingRun
    let isBusy: Bool
    var onAction: (TrainingCommand.Action) -> Void
    var onFinish: () -> Void
    @State private var screen = 1
    @State private var page = 0

    var body: some View {
        TabView(selection: $screen) {
            controls.tag(0)
            TabView(selection: $page) {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    WatchTrainingProgressPage(run: run, date: timeline.date)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { advance() }
                        .accessibilityAction(named: Text("Advance")) { advance() }
                }
                .accessibilityIdentifier("watchTrainingProgress")
                .tag(0)
                WatchTrainingDetailsPage(run: run)
                    .accessibilityIdentifier("watchTrainingDetails")
                    .tag(1)
            }
            .tabViewStyle(.verticalPage(transitionStyle: .identity))
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var controls: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Controls").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    control(run.pausedAt == nil ? "Pause" : "Resume",
                            symbol: run.pausedAt == nil ? "pause.fill" : "play.fill", color: .yellow) {
                        onAction(.pause)
                        showProgress()
                    }
                    control("Finish", symbol: "xmark", color: .red, action: onFinish)
                    control("Previous Block", symbol: "backward.end.fill", enabled: run.canReturnToPreviousBlock) {
                        onAction(.previousBlock)
                        showProgress()
                    }
                    .accessibilityIdentifier("watchPreviousBlock")
                    control(run.progress.stage == .series ? "Finish Series" : "Skip Rest",
                            symbol: "forward.end.fill", enabled: run.canAdvance) {
                        advance()
                        showProgress()
                    }
                }
                Button("Undo Last Transition", systemImage: "arrow.uturn.backward") {
                    onAction(.undo)
                    showProgress()
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(run.undo == nil || run.pausedAt != nil)
            }
            .disabled(isBusy)
            .padding(.horizontal, 10)
        }
        .accessibilityIdentifier("watchTrainingControls")
    }

    private func control(_ title: String, symbol: String, color: Color = .white,
                         enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 46, height: 46)
                    .background(color.opacity(0.18), in: Circle())
                Text(title).font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center).lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(title)
    }

    private func showProgress() {
        page = 0
        screen = 1
    }

    private func advance() {
        if run.canAdvance && !isBusy { onAction(.advance) }
    }
}

private struct WatchTrainingProgressPage: View {
    let run: TrainingRun
    let date: Date

    private var isResting: Bool { [.seriesRest, .blockRest].contains(run.progress.stage) }
    private var phaseColor: Color { isResting ? .yellow : .green }
    private var showsQueuedExercise: Bool { run.progress.stage == .blockRest && run.queuedExercise != nil }
    private var displayedExercise: TrainingExercise? {
        showsQueuedExercise ? run.queuedExercise : run.currentResult?.exercise
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 190
            VStack(alignment: .leading, spacing: compact ? 5 : 9) {
                exerciseCard(compact: compact)
                HStack(alignment: .center, spacing: 6) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(run.pausedAt != nil ? "Paused" : (isResting ? "Rest" : "Training"))
                            .font(.system(size: 11, weight: .medium))
                        Text(TrainingClock.label(run.remaining(at: date) ?? run.phaseElapsed(at: date)))
                            .font(.system(size: compact ? 38 : 46, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.65)
                    }
                    .foregroundStyle(phaseColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 2) {
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                        Text(run.metrics.heartRate.map { "\(Int($0))" } ?? "—")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("BPM").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    .font(.caption2)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Heart Rate")
                    .accessibilityValue(run.metrics.heartRate.map { "\(Int($0)) BPM" } ?? "Unavailable")
                }
                HStack {
                    Text("Total").foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text(TrainingClock.label(run.elapsed(at: date))).monospacedDigit()
                }
                .font(.system(size: compact ? 12 : 14, weight: .medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    private func exerciseCard(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(spacing: 4) {
                Text(showsQueuedExercise ? "Next · \(run.queuedExerciseNumber ?? 0) / \(run.plan.exerciseCount)"
                     : "Exercise \(run.exerciseNumber) / \(run.plan.exerciseCount)")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if run.isSimulatorPreview == true {
                    Text("Preview").foregroundStyle(.orange)
                }
            }
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1).minimumScaleFactor(0.8)
            Text(displayedExercise?.name ?? (run.progress.stage == .blockRest ? "Rest" :
                 (run.progress.stage == .readyToFinish ? "All Blocks Complete" : "Choose an Exercise")))
                .font(.system(size: compact ? 14 : 16, weight: .semibold))
                .lineLimit(2).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let exercise = displayedExercise {
                HStack(spacing: 4) {
                    Text(exercise.weightLabel)
                    Text("·").foregroundStyle(.secondary)
                    Text("\(exercise.repetitions) reps")
                }
                .font(.system(size: compact ? 11 : 12)).lineLimit(1).minimumScaleFactor(0.8)
                Text(showsQueuedExercise ? "Queued · \(exercise.sets) series" : run.phaseTitle)
                    .font(.system(size: compact ? 10 : 11, weight: .medium)).foregroundStyle(phaseColor)
                    .lineLimit(1).minimumScaleFactor(0.8)
            } else if run.progress.stage == .choosingExercise {
                Text("Select on iPhone").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 9 : 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

private struct WatchTrainingDetailsPage: View {
    let run: TrainingRun

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Details").font(.headline)
                if let queued = run.queuedExercise, let number = run.queuedExerciseNumber {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Up Next · Exercise \(number)").font(.caption2).foregroundStyle(.secondary)
                        Text(queued.name).font(.headline)
                        Text("\(queued.weightLabel) · \(queued.repetitions) reps · \(queued.sets) series")
                            .font(.caption)
                    }
                    Divider()
                }
                metric("Active Calories", value: run.metrics.activeCalories, unit: "kcal", symbol: "flame.fill", color: .pink)
                metric("Total Calories", value: run.metrics.totalCalories, unit: "kcal", symbol: "flame", color: .pink)
                metric("Average Heart Rate", value: run.metrics.averageHeartRate, unit: "BPM", symbol: "heart.fill", color: .red)
                metric("Maximum Heart Rate", value: run.metrics.maximumHeartRate, unit: "BPM", symbol: "heart.fill", color: .red)
                if let zone = run.metrics.currentZone {
                    Label("Zone \(zone + 1)", systemImage: "heart.text.clipboard")
                        .font(.subheadline)
                }
                ForEach(run.metrics.zones.sorted(by: { $0.id < $1.id })) { zone in
                    HStack {
                        Text("Zone \(zone.id + 1)")
                        Spacer()
                        Text(TrainingClock.label(zone.seconds)).monospacedDigit()
                    }
                    .font(.caption)
                }
                Text("Block \(min(run.progress.blockIndex + 1, run.plan.blocks.count)) / \(run.plan.blocks.count)")
                    .font(.caption).foregroundStyle(.secondary)
                if run.isSimulatorPreview == true {
                    Text("Simulator Preview · No Health recording").font(.caption2).foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 18)
        }
    }

    private func metric(_ title: String, value: Double?, unit: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Label(value.map { "\(Int($0)) \(unit)" } ?? "— \(unit)", systemImage: symbol)
                .font(.system(.title3, design: .rounded, weight: .medium))
                .foregroundStyle(color).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

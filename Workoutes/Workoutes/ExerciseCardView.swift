import SwiftUI
import SwiftData

struct ExerciseCardView: View {
    @Environment(ExerciseActivityController.self) private var exerciseActivity
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.indigo.rawValue
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .metric
    @Bindable var exercise: WorkoutExercise
    var workout: Workout? = nil
    var revealHighlight: UUID? = nil
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingWeightSheet = false
    @State private var selectedCountMetric: ExerciseCountMetric?

    private var accentColor: Color {
        ThemeColor.resolve(accentColorRawValue).color
    }

    private var isPlaying: Bool { exerciseActivity.isActive(exercise) && !exercise.isDone }
    private var isQueued: Bool { !isPlaying && exerciseActivity.isQueued(exercise) }

    private var stateValue: String {
        isQueued ? "Queued for next exercise block" : (exercise.isDone ? "Completed" : (isPlaying ? "Active" : "Not started"))
    }

    private var stateHint: String {
        if exerciseActivity.training?.hasActiveSession == true {
            if isQueued { return "Remove this exercise from the queue" }
            if isPlaying { return "Finish this series or skip the current rest" }
            return exerciseActivity.training?.run?.progress.stage == .choosingExercise
                ? "Use this exercise in the current training block" : "Queue this exercise for the next available exercise block"
        }
        return exercise.isDone ? "Unmark this exercise" : (isPlaying ? "Stop: completes after more than 10 seconds, otherwise cancels" : "Start this exercise")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ExerciseCardHeader(
                title: exercise.title, subtitle: exercise.subtitle, details: exercise.details,
                increaseLoadNextTime: exercise.increaseLoadNextTime, accentColor: accentColor,
                tagColors: exercise.tags.map(\.colorHex), tagIconNames: exercise.tags.map(\.iconName),
                tagNames: exercise.tags.map(\.name)
            ) {
                Button {
                    exerciseActivity.advanceState(exercise, context: modelContext)
                } label: {
                    if isQueued {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 28, weight: .semibold)).foregroundStyle(accentColor)
                            .frame(width: 44, height: 44)
                    } else {
                        ExerciseStatusSymbol(status: exercise.isDone ? .done : (isPlaying ? .playing : .empty),
                                             accentColor: accentColor)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(exerciseActivity.isUpdating)
                .accessibilityLabel("Exercise status")
                .accessibilityValue(stateValue)
                .accessibilityHint(stateHint)
                .accessibilityAddTraits(exercise.isDone || isPlaying || isQueued ? .isSelected : [])
                .accessibilityIdentifier("exerciseCompletion.\(exercise.title)")
                .sensoryFeedback(.selection, trigger: stateValue)
            }

            if isQueued {
                Label("Queued · Exercise \(exerciseActivity.training?.run?.queuedExerciseNumber ?? 0)", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .font(.caption.weight(.medium)).foregroundStyle(accentColor)
                    .accessibilityIdentifier("queuedExercise.\(exercise.title)")
            }

            Divider()

            HStack(spacing: 0) {
                Button { showingWeightSheet = true } label: {
                    ExerciseMetricView(
                        systemImage: "dumbbell.fill",
                        value: weightUnit.label(for: exercise.weight),
                        label: "Weight"
                    )
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Weight")
                .accessibilityValue("\(weightUnit.displayedWeight(from: exercise.weight).formatted()) \(weightUnit.accessibilityName)")
                .accessibilityHint("Opens the weight selector")
                .accessibilityIdentifier("exerciseWeight.\(exercise.title)")

                metricDivider

                Button { selectedCountMetric = .sets } label: {
                    ExerciseMetricView(
                        systemImage: "square.stack.3d.up.fill",
                        value: "\(exercise.numberOfSets) sets",
                        label: "Sets"
                    )
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Sets")
                .accessibilityValue("\(exercise.numberOfSets)")
                .accessibilityHint("Opens the sets selector")
                .accessibilityIdentifier("exerciseSets.\(exercise.title)")

                metricDivider

                Button { selectedCountMetric = .repetitions } label: {
                    ExerciseMetricView(
                        systemImage: "repeat",
                        value: "\(exercise.reps) reps",
                        label: "Repetitions"
                    )
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Repetitions")
                .accessibilityValue("\(exercise.reps)")
                .accessibilityHint("Opens the repetitions selector")
                .accessibilityIdentifier("exerciseRepetitions.\(exercise.title)")
            }

        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .subtleCardShadow()
        .overlay {
            ExerciseRevealHighlight(color: accentColor, trigger: revealHighlight)
        }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contextMenu {
            Button {
                showingEditSheet = true
            } label: {
                Label("Edit Exercise", systemImage: "pencil")
            }
            
            if let workout = workout {
                Button {
                    if let index = workout.exercises.firstIndex(of: exercise) {
                        workout.exercises.remove(at: index)
                    }
                } label: {
                    Label("Remove from Workout", systemImage: "minus.circle")
                }
            }
            
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete Permanently", systemImage: "trash")
            }
        }
        .padding(.horizontal)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                exercise.increaseLoadNextTime.toggle()
            } label: {
                Label("Bump", systemImage: "arrow.up.right.circle")
            }
            .tint(accentColor)
            .accessibilityHint(exercise.increaseLoadNextTime ? "Disables bump" : "Enables bump")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditExerciseSheet(exercise: exercise)
        }
        .sheet(isPresented: $showingWeightSheet) {
            ExerciseWeightSheet(exercise: exercise, unit: weightUnit)
                .tint(accentColor)
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedCountMetric) { metric in
            ExerciseCountSheet(exercise: exercise, metric: metric)
                .tint(accentColor)
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Are you sure you want to delete this exercise permanently? This will remove it from all workouts.",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                modelContext.delete(exercise)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1, height: 42)
    }
}

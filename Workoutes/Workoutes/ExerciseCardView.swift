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
    @State private var exerciseBeforeEditing: ExerciseCompletionSnapshot?

    private var accentColor: Color {
        ThemeColor.resolve(accentColorRawValue).color
    }

    private var isPlaying: Bool { exerciseActivity.isActive(exercise) && !exercise.isDone }
    private var isQueued: Bool { !isPlaying && exerciseActivity.isQueued(exercise) }

    private var stateValue: String {
        isQueued ? String(localized: "Queued for next exercise block") : (exercise.isDone ? String(localized: "Completed") : (isPlaying ? String(localized: "Active") : String(localized: "Not started")))
    }

    private var stateHint: String {
        if exerciseActivity.training?.hasActiveSession == true {
            if isQueued { return String(localized: "Remove this exercise from the queue") }
            if isPlaying { return String(localized: "Finish this series or skip the current rest") }
            return exerciseActivity.training?.run?.progress.stage == .choosingExercise
                ? String(localized: "Use this exercise in the current training block") : String(localized: "Queue this exercise for the next available exercise block")
        }
        return exercise.isDone ? String(localized: "Unmark this exercise") : (isPlaying ? String(localized: "Stop: completes after more than 10 seconds, otherwise cancels") : String(localized: "Start this exercise"))
    }

    var body: some View {
        ExerciseCardSurface {
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
                        ExerciseQueuedSymbol(accentColor: accentColor)
                    } else {
                        ExerciseStatusSymbol(status: exercise.isDone ? .done : (isPlaying ? .playing : .empty),
                                             accentColor: accentColor)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(exerciseActivity.isUpdating)
                .accessibilityLabel(String(localized: "Exercise status"))
                .accessibilityValue(stateValue)
                .accessibilityHint(stateHint)
                .accessibilityAddTraits(exercise.isDone || isPlaying || isQueued ? .isSelected : [])
                .accessibilityIdentifier("exerciseCompletion.\(exercise.title)")
                .sensoryFeedback(.selection, trigger: stateValue)
            }

            if isQueued {
                ExerciseQueuedLabel(number: exerciseActivity.training?.run?.queuedExerciseNumber,
                                    accentColor: accentColor)
                    .accessibilityIdentifier("queuedExercise.\(exercise.title)")
            }

            Divider()

            ExerciseCardMetrics {
                Button {
                    beginExerciseEdit()
                    showingWeightSheet = true
                } label: {
                    ExerciseMetricView(
                        systemImage: "dumbbell.fill",
                        value: weightUnit.label(for: exercise.weight),
                        label: String(localized: "Weight")
                    )
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "Weight"))
                .accessibilityValue("\(weightUnit.displayedWeight(from: exercise.weight).formatted()) \(weightUnit.accessibilityName)")
                .accessibilityHint(String(localized: "Opens the weight selector"))
                .accessibilityIdentifier("exerciseWeight.\(exercise.title)")

            } sets: {
                Button {
                    beginExerciseEdit()
                    selectedCountMetric = .sets
                } label: {
                    ExerciseMetricView(
                        systemImage: "square.stack.3d.up.fill",
                        value: String(localized: "\(exercise.numberOfSets) sets"),
                        label: String(localized: "Sets")
                    )
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "Sets"))
                .accessibilityValue("\(exercise.numberOfSets)")
                .accessibilityHint(String(localized: "Opens the sets selector"))
                .accessibilityIdentifier("exerciseSets.\(exercise.title)")

            } repetitions: {
                Button {
                    beginExerciseEdit()
                    selectedCountMetric = .repetitions
                } label: {
                    ExerciseMetricView(
                        systemImage: "repeat",
                        value: String(localized: "\(exercise.reps) reps"),
                        label: String(localized: "Repetitions")
                    )
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "Repetitions"))
                .accessibilityValue("\(exercise.reps)")
                .accessibilityHint(String(localized: "Opens the repetitions selector"))
                .accessibilityIdentifier("exerciseRepetitions.\(exercise.title)")
            }
        }
        .overlay {
            ExerciseRevealHighlight(color: accentColor, trigger: revealHighlight)
        }
        .contentShape(.contextMenuPreview, ExerciseCardStyle.shape)
        .contextMenu {
            Button {
                beginExerciseEdit()
                showingEditSheet = true
            } label: {
                Label(String(localized: "Edit Exercise"), systemImage: "pencil")
            }
            
            if let workout = workout {
                Button {
                    if let index = workout.exercises.firstIndex(of: exercise) {
                        workout.exercises.remove(at: index)
                    }
                } label: {
                    Label(String(localized: "Remove from Workout"), systemImage: "minus.circle")
                }
            }
            
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label(String(localized: "Delete Permanently"), systemImage: "trash")
            }
        }
        .padding(.horizontal)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                exercise.increaseLoadNextTime.toggle()
                exerciseActivity.training?.synchronizeExerciseEdit(exercise)
            } label: {
                Label(String(localized: "Bump"), systemImage: "arrow.up.right.circle")
            }
            .tint(accentColor)
            .accessibilityHint(exercise.increaseLoadNextTime ? String(localized: "Disables bump") : String(localized: "Enables bump"))
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: finishExerciseEdit) {
            EditExerciseSheet(exercise: exercise)
        }
        .sheet(isPresented: $showingWeightSheet, onDismiss: finishExerciseEdit) {
            ExerciseWeightSheet(exercise: exercise, unit: weightUnit)
                .tint(accentColor)
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedCountMetric, onDismiss: finishExerciseEdit) { metric in
            ExerciseCountSheet(exercise: exercise, metric: metric)
                .tint(accentColor)
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            String(localized: "Are you sure you want to delete this exercise permanently? This will remove it from all workouts."),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete Permanently"), role: .destructive) {
                modelContext.delete(exercise)
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
    }

    private func beginExerciseEdit() {
        exerciseBeforeEditing = ExerciseCompletionSnapshot(exercise: exercise)
    }

    private func finishExerciseEdit() {
        defer { exerciseBeforeEditing = nil }
        guard let exerciseBeforeEditing, !exercise.isDeleted,
              exerciseBeforeEditing != ExerciseCompletionSnapshot(exercise: exercise) else { return }
        exerciseActivity.training?.synchronizeExerciseEdit(exercise)
    }
}

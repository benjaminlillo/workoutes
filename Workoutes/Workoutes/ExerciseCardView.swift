import SwiftUI
import SwiftData

struct ExerciseCardView: View {
    @Environment(ExerciseActivityController.self) private var exerciseActivity
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .metric
    @Bindable var exercise: WorkoutExercise
    var workout: Workout? = nil
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingWeightSheet = false

    private var accentColor: Color {
        ThemeColor(rawValue: accentColorRawValue)?.color ?? .mint
    }

    private var isPlaying: Bool { exerciseActivity.isActive(exercise) && !exercise.isDone }

    private var stateValue: String {
        exercise.isDone ? "Completed" : (isPlaying ? "Active" : "Not started")
    }

    private var stateHint: String {
        exercise.isDone ? "Unmark this exercise" : (isPlaying ? "Stop and mark completed" : "Start this exercise")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.title)
                        .font(.title3.weight(.bold))

                    if !exercise.subtitle.isEmpty {
                        Text(exercise.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !exercise.details.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Image(systemName: "doc.text")
                            Text(exercise.details)
                                .lineLimit(2)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 5) {
                    Button {
                        exerciseActivity.advanceState(exercise, context: modelContext)
                    } label: {
                        ExerciseStatusSymbol(status: exercise.isDone ? .done : (isPlaying ? .playing : .empty),
                                             accentColor: accentColor)
                    }
                    .buttonStyle(.borderless)
                    .disabled(exerciseActivity.isUpdating)
                    .accessibilityLabel("Exercise status")
                    .accessibilityValue(stateValue)
                    .accessibilityHint(stateHint)
                    .accessibilityAddTraits(exercise.isDone || isPlaying ? .isSelected : [])
                    .accessibilityIdentifier("exerciseCompletion.\(exercise.title)")
                    .sensoryFeedback(.selection, trigger: stateValue)

                    if !exercise.tags.isEmpty {
                        tagBars
                    }

                    if exercise.increaseLoadNextTime {
                        ExerciseBumpBadge(color: accentColor)
                    }
                }
                .frame(width: 68)
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
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Weight")
                .accessibilityValue("\(weightUnit.displayedWeight(from: exercise.weight).formatted()) \(weightUnit.accessibilityName)")
                .accessibilityHint("Opens the weight selector")
                .accessibilityIdentifier("exerciseWeight.\(exercise.title)")

                metricDivider

                ExerciseMetricView(
                    systemImage: "square.stack.3d.up.fill",
                    value: "\(exercise.numberOfSets) sets",
                    label: "Sets"
                )

                metricDivider

                ExerciseMetricView(
                    systemImage: "repeat",
                    value: "\(exercise.reps) reps",
                    label: "Repetitions"
                )
            }

        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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

    private var tagBars: some View {
        HStack(spacing: 3) {
            ForEach(exercise.tags) { tag in
                Circle()
                    .fill(Color(hex: tag.colorHex))
                    .frame(width: 7, height: 7)
                    .accessibilityLabel("Tag: \(tag.name)")
            }
        }
        .fixedSize()
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1, height: 42)
    }
}

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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.title)
                        .font(.headline)

                    
                    if !exercise.subtitle.isEmpty {
                        Text(exercise.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if !exercise.details.isEmpty {
                        Text(exercise.details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(exercise.numberOfSets) Sets")
                        .font(.subheadline.bold())
                    Text("\(exercise.reps) Reps")
                        .font(.subheadline.bold())
                }
            }
            
            Divider()

            HStack {
                Button { showingWeightSheet = true } label: {
                    HStack(spacing: 5) {
                        Text(weightUnit.label(for: exercise.weight))
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(accentColor)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Weight")
                .accessibilityValue("\(weightUnit.displayedWeight(from: exercise.weight).formatted()) \(weightUnit.accessibilityName)")
                .accessibilityHint("Opens the weight selector")
                .accessibilityIdentifier("exerciseWeight.\(exercise.title)")
                
                Spacer()
                
                Toggle("Increase Next", isOn: $exercise.increaseLoadNextTime)
                    .font(.caption)
                    .toggleStyle(.button)
                    .tint(exercise.increaseLoadNextTime ? .blue : .gray)
                
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
            }

            if !exercise.tags.isEmpty {
                HStack {
                    tagBars
                    Spacer(minLength: 0)
                }
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
        HStack(spacing: 5) {
            ForEach(exercise.tags) { tag in
                Capsule()
                    .fill(Color(hex: tag.colorHex))
                    .frame(maxWidth: 24)
                    .frame(height: 4)
                    .accessibilityLabel("Tag: \(tag.name)")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

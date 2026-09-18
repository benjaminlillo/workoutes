import SwiftUI
import SwiftData

struct ExerciseCardView: View {
    @Environment(ExerciseActivityController.self) private var exerciseActivity
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    @Bindable var exercise: WorkoutExercise
    var workout: Workout? = nil
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

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

    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(exercise.title)
                            .font(.headline)
                        
                        if !exercise.tags.isEmpty {
                            ForEach(exercise.tags) { tag in
                                Circle()
                                    .fill(Color(hex: tag.colorHex))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
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
                Text("Weight:")
                    .font(.subheadline)
                
                TextField("Weight", value: $exercise.weight, formatter: formatter)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                
                Spacer()
                
                Toggle("Increase Next", isOn: $exercise.increaseLoadNextTime)
                    .font(.caption)
                    .toggleStyle(.button)
                    .tint(exercise.increaseLoadNextTime ? .blue : .gray)
                
                Button {
                    exerciseActivity.advanceState(exercise, context: modelContext)
                } label: {
                    ZStack {
                        Circle()
                            .fill(exercise.isDone ? accentColor : .clear)
                        Circle()
                            .strokeBorder(exercise.isDone || isPlaying ? accentColor : .gray, lineWidth: 2)
                        if exercise.isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                        } else if isPlaying {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
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
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
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
}

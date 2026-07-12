import SwiftUI
import SwiftData

struct ExerciseCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: WorkoutExercise
    var workout: Workout? = nil
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    
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
                
                Toggle("Done", isOn: $exercise.isDone)
                    .font(.caption)
                    .toggleStyle(.button)
                    .tint(exercise.isDone ? .green : .gray)
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

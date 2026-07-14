import SwiftUI
import SwiftData

struct CreateWorkoutSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var selectedTags: Set<Tag> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Workout Details")) {
                    TextField("Workout Name", text: $name)
                }
                
                if !allTags.isEmpty {
                    Section(header: Text("Auto-Populate with Tags"), footer: Text("All exercises containing these tags will be automatically added to your workout.")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(allTags) { tag in
                                    let isSelected = selectedTags.contains(tag)
                                    Text(tag.name)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color(hex: tag.colorHex) : Color.gray.opacity(0.2))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .cornerRadius(16)
                                        .onTapGesture {
                                            if isSelected {
                                                selectedTags.remove(tag)
                                            } else {
                                                selectedTags.insert(tag)
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var exercisesToAdd: [WorkoutExercise] = []
                        for tag in selectedTags {
                            for exercise in tag.exercises {
                                if !exercisesToAdd.contains(where: { $0.persistentModelID == exercise.persistentModelID }) {
                                    exercisesToAdd.append(exercise)
                                }
                            }
                        }
                        
                        let workout = Workout(name: name, exercises: exercisesToAdd)
                        modelContext.insert(workout)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CreateWorkoutSheet()
}

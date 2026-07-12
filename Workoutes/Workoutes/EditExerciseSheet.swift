import SwiftUI
import SwiftData

struct EditExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: WorkoutExercise
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Title", text: $exercise.title)
                    TextField("Subtitle (Optional)", text: $exercise.subtitle)
                    TextField("Details (Optional)", text: $exercise.details)
                }
                
                Section(header: Text("Targets")) {
                    Stepper("Sets: \(exercise.numberOfSets)", value: $exercise.numberOfSets, in: 1...20)
                    Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...100)
                }
                
                if !allTags.isEmpty {
                    Section(header: Text("Tags")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(allTags) { tag in
                                    let isSelected = exercise.tags.contains(tag)
                                    Text(tag.name)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color(hex: tag.colorHex) : Color.gray.opacity(0.2))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .cornerRadius(16)
                                        .onTapGesture {
                                            if let index = exercise.tags.firstIndex(of: tag) {
                                                exercise.tags.remove(at: index)
                                            } else {
                                                exercise.tags.append(tag)
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(exercise.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

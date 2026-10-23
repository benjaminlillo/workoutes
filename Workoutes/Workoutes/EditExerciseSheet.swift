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
                        .subtleFormRowShadow(.first)
                    TextField("Subtitle (Optional)", text: $exercise.subtitle)
                        .subtleFormRowShadow(.middle)
                    TextField("Details (Optional)", text: $exercise.details)
                        .subtleFormRowShadow(.last)
                }
                
                Section(header: Text("Targets")) {
                    Stepper("Sets: \(exercise.numberOfSets)", value: $exercise.numberOfSets, in: 1...20)
                        .subtleFormRowShadow(.first)
                    Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...100)
                        .subtleFormRowShadow(.last)
                }
                
                if !allTags.isEmpty {
                    Section(header: Text("Tags")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(allTags) { tag in
                                    let isSelected = exercise.tags.contains(tag)
                                    TagSelectionLabel(tag: tag, isSelected: isSelected)
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
                        .subtleFormRowShadow()
                    }
                }
            }
            .transparentNavigationChrome()
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

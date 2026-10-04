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
                        .subtleFormRowBorder(.first)
                    TextField("Subtitle (Optional)", text: $exercise.subtitle)
                        .subtleFormRowBorder(.middle)
                    TextField("Details (Optional)", text: $exercise.details)
                        .subtleFormRowBorder(.last)
                }
                
                Section(header: Text("Targets")) {
                    Stepper("Sets: \(exercise.numberOfSets)", value: $exercise.numberOfSets, in: 1...20)
                        .subtleFormRowBorder(.first)
                    Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...100)
                        .subtleFormRowBorder(.last)
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
                        .subtleFormRowBorder()
                    }
                }
            }
            .transparentNavigationChrome()
            .defaultScreenBackground()
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

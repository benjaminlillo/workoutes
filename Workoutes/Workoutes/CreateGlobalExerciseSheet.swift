import SwiftUI
import SwiftData

struct CreateGlobalExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @State private var selectedTags: Set<Tag> = []
    
    @State private var title = ""
    @State private var subtitle = ""
    @State private var details = ""
    @State private var numberOfSets: Int = 3
    @State private var reps: Int = 10
    @State private var weight: Double = 0.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Title", text: $title)
                    TextField("Subtitle (Optional)", text: $subtitle)
                    TextField("Details (Optional)", text: $details)
                }
                
                Section(header: Text("Targets")) {
                    Stepper("Sets: \(numberOfSets)", value: $numberOfSets, in: 1...20)
                    Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                }
                
                if !allTags.isEmpty {
                    Section(header: Text("Tags")) {
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
                                            if isSelected { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                                        }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Starting Load")) {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exercise = WorkoutExercise(
                            title: title,
                            subtitle: subtitle,
                            details: details,
                            numberOfSets: numberOfSets,
                            reps: reps,
                            increaseLoadNextTime: false,
                            weight: weight,
                            isDone: false
                        )
                        exercise.tags = Array(selectedTags)
                        modelContext.insert(exercise)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

import SwiftUI
import SwiftData

struct CreateExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let workout: Workout
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @State private var selectedTags: Set<Tag> = []
    @Query(sort: \WorkoutExercise.title) private var allExercises: [WorkoutExercise]
    
    @State private var title = ""
    @State private var subtitle = ""
    @State private var details = ""
    @State private var numberOfSets: Int = 3
    @State private var reps: Int = 10
    @State private var weight: Double = 0.0
    
    var availableExercises: [WorkoutExercise] {
        allExercises.filter { !workout.exercises.contains($0) }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if !availableExercises.isEmpty {
                    Section(header: Text("Add Existing Exercise")) {
                        ForEach(Array(availableExercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                            Button(action: {
                                addExistingExercise(exercise)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(exercise.title)
                                            .foregroundColor(.primary)
                                        if !exercise.subtitle.isEmpty {
                                            Text(exercise.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                            .subtleFormRowShadow(.row(at: index, count: availableExercises.count))
                        }
                    }
                }
                
                Section(header: Text("Create New Exercise")) {
                    TextField("Title", text: $title)
                        .subtleFormRowShadow(.first)
                    TextField("Subtitle (Optional)", text: $subtitle)
                        .subtleFormRowShadow(.middle)
                    TextField("Details (Optional)", text: $details)
                        .subtleFormRowShadow(.middle)
                    Text("Targets")
                        .subtleFormRowShadow(.middle)
                    Stepper("Sets: \(numberOfSets)", value: $numberOfSets, in: 1...20)
                        .subtleFormRowShadow(.middle)
                    Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                        .subtleFormRowShadow(.middle)
                    
                    if !allTags.isEmpty {
                        Text("Tags")
                            .subtleFormRowShadow(.middle)
                        Group {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(allTags) { tag in
                                        let isSelected = selectedTags.contains(tag)
                                        TagSelectionLabel(tag: tag, isSelected: isSelected)
                                            .onTapGesture {
                                                if isSelected { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                                            }
                                    }
                                }
                            }
                            .subtleFormRowShadow(.middle)
                        }
                    }
                    
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    .subtleFormRowShadow(.middle)
                    
                    Button("Create and Add") {
                        createNewExercise()
                    }
                    .disabled(title.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(title.isEmpty ? .gray : .blue)
                    .subtleFormRowShadow(.last)
                }
            }
            .transparentNavigationChrome()
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addExistingExercise(_ exercise: WorkoutExercise) {
        workout.exercises.append(exercise)
        dismiss()
    }
    
    private func createNewExercise() {
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
        workout.exercises.append(exercise)
        dismiss()
    }
}

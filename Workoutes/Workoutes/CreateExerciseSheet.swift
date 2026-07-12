import SwiftUI
import SwiftData

struct CreateExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let workout: Workout
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
                        ForEach(availableExercises) { exercise in
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
                        }
                    }
                }
                
                Section(header: Text("Create New Exercise")) {
                    TextField("Title", text: $title)
                    TextField("Subtitle (Optional)", text: $subtitle)
                    TextField("Details (Optional)", text: $details)
                    
                    Stepper("Sets: \(numberOfSets)", value: $numberOfSets, in: 1...20)
                    Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                    
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Button("Create and Add") {
                        createNewExercise()
                    }
                    .disabled(title.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(title.isEmpty ? .gray : .blue)
                }
            }
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
        modelContext.insert(exercise)
        workout.exercises.append(exercise)
        dismiss()
    }
}

import SwiftUI
import SwiftData

struct CreateGlobalExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
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
                        modelContext.insert(exercise)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

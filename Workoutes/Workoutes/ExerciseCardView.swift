import SwiftUI
import SwiftData

struct ExerciseCardView: View {
    @Bindable var exercise: WorkoutExercise
    
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
                    Text(exercise.title)
                        .font(.headline)
                    
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
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

import SwiftUI

struct ExerciseWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: WorkoutExercise
    let unit: WeightUnit
    @State private var selectedWeight: Int
    private let maximumWeight: Int

    init(exercise: WorkoutExercise, unit: WeightUnit) {
        self.exercise = exercise
        self.unit = unit
        let displayed = unit.displayedWeight(from: exercise.weight)
        let initialWeight = displayed.isFinite ? Int((max(0, displayed) / unit.pickerStep).rounded()) : 0
        _selectedWeight = State(initialValue: initialWeight)
        maximumWeight = max(Int((unit.displayedWeight(from: 500) / unit.pickerStep).rounded(.up)), initialWeight)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text(exercise.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Picker("Weight", selection: $selectedWeight) {
                    ForEach(0...maximumWeight, id: \.self) { weight in
                        Text("\((Double(weight) * unit.pickerStep).formatted(.number.precision(.fractionLength(0...1)))) \(unit.symbol)")
                            .tag(weight)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 216)
                .accessibilityIdentifier("exerciseWeightPicker")
                .onChange(of: selectedWeight) { _, weight in
                    exercise.weight = unit.kilograms(from: Double(weight) * unit.pickerStep)
                }
            }
            .padding(.horizontal)
            .navigationTitle("Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

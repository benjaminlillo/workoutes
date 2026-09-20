import SwiftUI

enum ExerciseCountMetric: String, Identifiable, CaseIterable {
    case sets
    case repetitions

    var id: Self { self }

    var title: String {
        switch self {
        case .sets: "Sets"
        case .repetitions: "Repetitions"
        }
    }

    var maximum: Int {
        switch self {
        case .sets: 20
        case .repetitions: 100
        }
    }

    var keyPath: ReferenceWritableKeyPath<WorkoutExercise, Int> {
        switch self {
        case .sets: \WorkoutExercise.numberOfSets
        case .repetitions: \WorkoutExercise.reps
        }
    }

    func label(for value: Int) -> String {
        switch self {
        case .sets: "\(value) sets"
        case .repetitions: "\(value) reps"
        }
    }
}

struct ExerciseCountSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: WorkoutExercise
    let metric: ExerciseCountMetric
    @State private var selectedValue: Int
    private let maximum: Int

    init(exercise: WorkoutExercise, metric: ExerciseCountMetric) {
        self.exercise = exercise
        self.metric = metric
        let initialValue = max(1, exercise[keyPath: metric.keyPath])
        _selectedValue = State(initialValue: initialValue)
        maximum = max(metric.maximum, initialValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text(exercise.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Picker(metric.title, selection: $selectedValue) {
                    ForEach(1...maximum, id: \.self) { value in
                        Text(metric.label(for: value))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 216)
                .accessibilityIdentifier("exercise\(metric.title)Picker")
                .onChange(of: selectedValue) { _, value in
                    exercise[keyPath: metric.keyPath] = value
                }
            }
            .padding(.horizontal)
            .transparentNavigationChrome()
            .navigationTitle(metric.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

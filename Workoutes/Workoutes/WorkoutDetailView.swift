import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: Workout
    @State private var showingAddSheet = false
    
    var body: some View {
        List {
            if let activeExercise = workout.exercises.first(where: { $0.isActive }) {
                ExerciseCardView(exercise: activeExercise, workout: workout)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
            }
            
            ForEach(workout.exercises.filter { !$0.isActive }) { exercise in
                ExerciseCardView(exercise: exercise, workout: workout)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
            }
            .onDelete(perform: deleteExercises)
        }
        .listStyle(.plain)
        .navigationTitle(workout.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CreateExerciseSheet(workout: workout)
        }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            let inactiveExercises = workout.exercises.filter { !$0.isActive }
            for index in offsets.sorted(by: >) {
                if let exerciseIndex = workout.exercises.firstIndex(of: inactiveExercises[index]) {
                    workout.exercises.remove(at: exerciseIndex)
                }
            }
        }
    }
}

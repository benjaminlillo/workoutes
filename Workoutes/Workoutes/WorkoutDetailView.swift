import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: Workout
    @State private var showingAddSheet = false
    
    var body: some View {
        List {
            ForEach(workout.exercises) { exercise in
                ExerciseCardView(exercise: exercise)
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
        }
        .sheet(isPresented: $showingAddSheet) {
            CreateExerciseSheet(workout: workout)
        }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let exercise = workout.exercises[index]
                modelContext.delete(exercise)
            }
        }
    }
}

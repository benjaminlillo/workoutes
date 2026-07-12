import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutExercise.title) private var exercises: [WorkoutExercise]
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(exercises) { exercise in
                    ExerciseCardView(exercise: exercise)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 4)
                }
                .onDelete(perform: deleteExercises)
            }
            .listStyle(.plain)
            .navigationTitle("All Exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                CreateGlobalExerciseSheet()
            }
        }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let exercise = exercises[index]
                // Aquí sí borramos permanentemente de la base de datos
                modelContext.delete(exercise)
            }
        }
    }
}

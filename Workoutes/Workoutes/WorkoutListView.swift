import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [Workout]
    @State private var showingAddSheet = false
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        Text(workout.name)
                            .font(.headline)
                    }
                    .listRowInsets(EdgeInsets(top: 26, leading: 32, bottom: 26, trailing: 32))
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    )
                }
                .onDelete(perform: deleteWorkouts)
            }
            .listStyle(.plain)
            .transparentNavigationChrome()
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Workout", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                CreateWorkoutSheet()
            }
        }
        .tint(ThemeColor(rawValue: accentColorRawValue)?.color ?? .mint)
    }
    
    private func deleteWorkouts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(workouts[index])
            }
        }
    }
}

#Preview {
    WorkoutListView()
        .environment(ExerciseActivityController())
        .modelContainer(for: Workout.self, inMemory: true)
}

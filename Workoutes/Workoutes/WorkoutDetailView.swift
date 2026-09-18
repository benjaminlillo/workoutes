import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: Workout
    @State private var showingAddSheet = false
    @State private var showingBackgroundSheet = false
    @State private var background: ExerciseBackgroundStore?
    @State private var backgroundError: String?
    private var backgroundTagColors: [String] {
        var seen = Set<PersistentIdentifier>()
        return workout.exercises.flatMap(\.tags)
            .filter { seen.insert($0.persistentModelID).inserted }
            .sorted { $0.name < $1.name }.map(\.colorHex)
    }
    
    var body: some View {
        List {
            ForEach(workout.exercises) { exercise in
                ExerciseCardView(exercise: exercise, workout: workout)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 10)
            }
            .onDelete(perform: deleteExercises)
        }
        .listStyle(.plain)
        .scrollContentBackground(background == nil ? .visible : .hidden)
        .background {
            if let background { ScreenBackgroundView(background: background, tagColors: backgroundTagColors).ignoresSafeArea() }
        }
        .navigationTitle(workout.name)
        .task {
            do {
                if workout.backgroundID == nil { workout.backgroundID = UUID().uuidString }
                try modelContext.save()
                if let id = workout.backgroundID {
                    background = ExerciseBackgroundStore(identifier: "workout-" + id)
                }
            } catch { backgroundError = error.localizedDescription }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Customize Background", systemImage: "paintpalette") { showingBackgroundSheet = true }
                    .disabled(background == nil)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ResetCompletedExercisesButton(exercises: workout.exercises)
            }
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
        .sheet(isPresented: $showingBackgroundSheet) {
            if let background {
                BackgroundCustomizationSheet(background: background, title: "Workout Background", tagColors: backgroundTagColors)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .alert("Background", isPresented: Binding(
            get: { backgroundError != nil }, set: { if !$0 { backgroundError = nil } }
        )) {
            Button("OK", role: .cancel) { backgroundError = nil }
        } message: { Text(backgroundError ?? "") }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            for index in offsets.sorted(by: >) {
                workout.exercises.remove(at: index)
            }
        }
    }
}

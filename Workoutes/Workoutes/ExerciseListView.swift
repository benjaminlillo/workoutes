import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutExercise.title) private var allExercises: [WorkoutExercise]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @State private var showingAddExerciseSheet = false
    @State private var showingAddTagSheet = false
    @State private var editingTag: Tag?
    
    @State private var selectedTagIDs: Set<PersistentIdentifier> = []
    
    var filteredExercises: [WorkoutExercise] {
        if selectedTagIDs.isEmpty {
            return allExercises
        }
        return allExercises.filter { exercise in
            exercise.tags.contains { tag in
                selectedTagIDs.contains(tag.persistentModelID)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allTags) { tag in
                            let isSelected = selectedTagIDs.contains(tag.persistentModelID)
                            Text(tag.name)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color(hex: tag.colorHex) : Color.gray.opacity(0.2))
                                .foregroundColor(isSelected ? .white : .primary)
                                .cornerRadius(16)
                                .onTapGesture {
                                    if isSelected {
                                        selectedTagIDs.remove(tag.persistentModelID)
                                    } else {
                                        selectedTagIDs.insert(tag.persistentModelID)
                                    }
                                }
                                .onLongPressGesture {
                                    editingTag = tag
                                }
                        }
                        
                        Button(action: { showingAddTagSheet = true }) {
                            Image(systemName: "plus")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(16)
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemBackground))
                
                Divider()
                
                List {
                    ForEach(filteredExercises) { exercise in
                        ExerciseCardView(exercise: exercise)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteExercises)
                }
                .listStyle(.plain)
            }
            .navigationTitle("All Exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddExerciseSheet = true }) {
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
            .sheet(isPresented: $showingAddExerciseSheet) {
                CreateGlobalExerciseSheet()
            }
            .sheet(isPresented: $showingAddTagSheet) {
                ManageTagSheet()
            }
            .sheet(item: $editingTag) { tag in
                ManageTagSheet(editingTag: tag)
            }
        }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let exercise = filteredExercises[index]
                modelContext.delete(exercise)
            }
        }
    }
}

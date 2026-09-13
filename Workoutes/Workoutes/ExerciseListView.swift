import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(ExerciseBackgroundStore.self) private var background
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
            .scrollContentBackground(.hidden)
            // Keep the List as the primary scroll view so the native large title
            // collapses. The accessory bar follows the navigation safe area.
            .safeAreaInset(edge: .top, spacing: 0) {
                tagBar
            }
            .background {
                if let image = background.image {
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .navigationTitle("All Exercises")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: allTags.map(\.persistentModelID)) { _, ids in
                selectedTagIDs.formIntersection(ids)
            }
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
    
    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 12) {
                    ForEach(allTags) { tag in
                        let isSelected = selectedTagIDs.contains(tag.persistentModelID)
                        Button {
                            withAnimation(.smooth) {
                                if isSelected {
                                    selectedTagIDs.remove(tag.persistentModelID)
                                } else {
                                    selectedTagIDs.insert(tag.persistentModelID)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle.fill")
                                    .font(isSelected ? .subheadline : .system(size: 8))
                                    .foregroundStyle(isSelected ? Color.primary : Color(hex: tag.colorHex))
                                Text(tag.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            .regular.tint(isSelected ? Color(hex: tag.colorHex).opacity(0.45) : .clear).interactive(),
                            in: .capsule
                        )
                        .accessibilityLabel(tag.name)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityValue(isSelected ? "Selected" : "Not selected")
                        .contextMenu {
                            Button {
                                editingTag = tag
                            } label: {
                                Label("Edit Tag", systemImage: "pencil")
                            }
                        }
                        .accessibilityAction(named: "Edit Tag") { editingTag = tag }
                    }

                    Button(action: { showingAddTagSheet = true }) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Add Tag")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        // Let Liquid Glass shadows fade outside the horizontal scroll bounds.
        .scrollClipDisabled()
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

import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutExercise.title) private var allExercises: [WorkoutExercise]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @State private var showingAddExerciseSheet = false
    @State private var showingAddTagSheet = false
    @State private var editingTag: Tag?
    @State private var tagPendingDeletion: Tag?
    
    @State var navigation = ExerciseNavigation()
    @State private var highlightedRequest: ExerciseRevealRequest?
    @State private var revealPosition: ExerciseRevealPosition?
    @State private var viewportSize: CGSize = .zero
    @State private var displayedTagIDs: Set<PersistentIdentifier>?
    @State private var filterTransition = ExerciseFilterTransition()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var filterChange: FilterChange {
        FilterChange(tags: navigation.selectedTagIDs, reveal: navigation.revealRequest)
    }
    private var tagSelection: Binding<PersistentIdentifier?> {
        Binding(get: { navigation.selectedTagIDs.first },
                set: { navigation.selectedTagIDs = $0.map { [$0] } ?? [] })
    }
    
    var filteredExercises: [WorkoutExercise] {
        let tagIDs = displayedTagIDs ?? navigation.selectedTagIDs
        if tagIDs.isEmpty {
            return allExercises
        }
        return allExercises.filter { exercise in
            exercise.tags.contains { tag in
                tagIDs.contains(tag.persistentModelID)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(filteredExercises) { exercise in
                        ExerciseCardView(
                            exercise: exercise,
                            revealHighlight: highlightedRequest?.exerciseID == exercise.persistentModelID
                                ? highlightedRequest?.id : nil
                        )
                            .id(exercise.persistentModelID)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 10)
                            .background {
                                if let request = navigation.revealRequest,
                                   request.exerciseID == exercise.persistentModelID {
                                    GeometryReader { geometry in
                                        Color.clear.preference(
                                            key: ExerciseRevealPositionKey.self,
                                            value: ExerciseRevealPosition(
                                                request: request,
                                                frame: geometry.frame(in: .named("exerciseList"))
                                            )
                                        )
                                    }
                                }
                            }
                    }
                    .onDelete(perform: deleteExercises)
                }
                .coordinateSpace(name: "exerciseList")
                .onGeometryChange(for: CGSize.self) { $0.size } action: { viewportSize = $0 }
                .onPreferenceChange(ExerciseRevealPositionKey.self) { revealPosition = $0 }
                .onChange(of: filterChange, initial: true) { _, _ in transitionFilter() }
                .task(id: FilterChange(tags: displayedTagIDs ?? navigation.selectedTagIDs,
                                       reveal: navigation.revealRequest)) {
                    guard let request = navigation.revealRequest,
                          navigation.selectedTab == .exercises,
                          filteredExercises.contains(where: { $0.persistentModelID == request.exerciseID }) else { return }
                    highlightedRequest = nil
                    // Let the selected tab and the newly unfiltered rows finish their layout.
                    await Task.yield()
                    guard !Task.isCancelled, navigation.revealRequest == request else { return }
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) {
                        proxy.scrollTo(request.exerciseID, anchor: .center)
                    }
                }
                .task(id: revealPosition) {
                    guard let position = revealPosition else { return }
                    // List scrolling does not participate in SwiftUI animation completions.
                    // Wait until the destination row's visible position has settled instead.
                    do { try await Task.sleep(for: .milliseconds(150)) }
                    catch { return }
                    let viewport = CGRect(origin: .zero, size: viewportSize)
                    let visibleHeight = position.frame.intersection(viewport).height
                    guard navigation.revealRequest == position.request,
                          navigation.selectedTab == .exercises,
                          visibleHeight >= min(position.frame.height, viewport.height) * 0.8 else { return }
                    highlightedRequest = position.request
                    navigation.revealRequest = nil
                }
                .listStyle(.plain)
                .transparentNavigationChrome()
                .scrollContentBackground(.hidden)
                .overlay {
                    ExerciseFilterTransitionLayer(transition: filterTransition,
                        showsEmptyMessage: filteredExercises.isEmpty && !(displayedTagIDs ?? navigation.selectedTagIDs).isEmpty)
                        .allowsHitTesting(false)
                }
                .background { DefaultScreenBackground().ignoresSafeArea() }
                .navigationTitle("All Exercises")
                .navigationBarTitleDisplayMode(.large)
                .onChange(of: allTags.map(\.persistentModelID)) { _, ids in
                    navigation.selectedTagIDs.formIntersection(ids)
                }
                .onDisappear {
                    filterTransition.cancel()
                    displayedTagIDs = nil
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        ResetCompletedExercisesButton(exercises: allExercises)
                            .tint(.primary)
                        TagWheelMenu(tags: allTags, selection: tagSelection.wrappedValue,
                                     onChoose: { tag in
                                         let id = tag.persistentModelID
                                         tagSelection.wrappedValue = tagSelection.wrappedValue == id ? nil : id
                                     }, onDeselect: { navigation.selectedTagIDs.removeAll() },
                                     onAdd: { showingAddTagSheet = true },
                                     onEdit: { editingTag = $0 },
                                     onDelete: { tagPendingDeletion = $0 })
                            .frame(width: ExerciseToolbarStyle.targetSize, height: ExerciseToolbarStyle.targetSize)
                    }
                    ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddExerciseSheet = true }) {
                            ExerciseToolbarLabel(title: "Add Exercise", systemImage: "plus")
                        }
                        .tint(.primary)
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
                .confirmationDialog("Delete Tag?", isPresented: Binding(
                    get: { tagPendingDeletion != nil },
                    set: { if !$0 { tagPendingDeletion = nil } }
                ), titleVisibility: .visible, presenting: tagPendingDeletion) { tag in
                    Button("Delete Tag", role: .destructive) {
                        withAnimation {
                            navigation.selectedTagIDs.remove(tag.persistentModelID)
                            modelContext.delete(tag)
                        }
                        tagPendingDeletion = nil
                    }
                    Button("Cancel", role: .cancel) { tagPendingDeletion = nil }
                } message: { tag in
                    Text("Delete \"\(tag.name)\"? Your exercises will be kept.")
                }
                .sheet(item: $editingTag) { tag in
                    ManageTagSheet(editingTag: tag)
                }
            }
        }
        .overlay {
            DockableTagWheel(tags: allTags,
                             selection: tagSelection,
                             onAdd: { showingAddTagSheet = true },
                             onEdit: { editingTag = $0 },
                             onDelete: { tagPendingDeletion = $0 })
        }
    }

    private func transitionFilter() {
        let change = filterChange
        guard displayedTagIDs != nil, !reduceMotion, change.reveal == nil else {
            filterTransition.cancel()
            withoutFilterAnimation {
                displayedTagIDs = change.tags
            }
            return
        }
        guard displayedTagIDs != change.tags else { return }
        filterTransition.begin()
        withoutFilterAnimation {
            displayedTagIDs = change.tags
        }
    }

    private func withoutFilterAnimation(_ update: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, update)
    }

    private struct FilterChange: Equatable {
        let tags: Set<PersistentIdentifier>
        let reveal: ExerciseRevealRequest?
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

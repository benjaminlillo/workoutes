import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ExerciseActivityController.self) private var exerciseActivity
    @Query(sort: \WorkoutExercise.title) private var allExercises: [WorkoutExercise]
    @Query(sort: \TagGroup.name) private var groups: [TagGroup]
    
    @Namespace private var toolbarGlass
    @State private var showingAddExerciseSheet = false
    @State private var showingTagManagement = false
    
    @State var navigation = ExerciseNavigation()
    @State private var highlightedRequest: ExerciseRevealRequest?
    @State private var revealPosition: ExerciseRevealPosition?
    @State private var viewportSize: CGSize = .zero
    @State private var displayedFilterChange: FilterChange?
    @State private var filterTransition = ExerciseFilterTransition()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var filterChange: FilterChange {
        FilterChange(tags: navigation.selectedGroupTagIDs, reveal: navigation.revealRequest)
    }

    private var displayedFilter: Set<PersistentIdentifier>? {
        if let displayedFilterChange { return displayedFilterChange.tags }
        return navigation.selectedGroupTagIDs
    }

    private var groupSelection: Binding<PersistentIdentifier?> {
        Binding(get: { navigation.selectedGroup?.persistentModelID },
                set: { id in navigation.selectedGroup = groups.first { $0.persistentModelID == id } })
    }

    private var pageTitle: String {
        navigation.selectedGroup?.name ?? String(localized: "All Exercises")
    }

    private var activeExercise: WorkoutExercise? {
        allExercises.first { !$0.isDeleted && exerciseActivity.isActive($0) }
    }
    
    /// Reserve the host's maximum width so UIKit doesn't jump its bar-item frame.
    /// Only the inner capsule resizes; SwiftUI interpolates its native glass surface.
    private var exerciseToolbarActions: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                if let activeExercise {
                    Button {
                        navigation.reveal(activeExercise)
                    } label: {
                        ExerciseToolbarLabel(title: "Show Active Exercise",
                                             systemImage: "figure.strengthtraining.traditional")
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(activeExercise.title)
                    .accessibilityIdentifier("showActiveExercise")
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
                ResetCompletedExercisesButton(exercises: allExercises)
                    .buttonStyle(.plain)
                    .tint(.primary)
                Button {
                    showingTagManagement = true
                } label: {
                    ExerciseToolbarLabel(title: "Manage Tags", systemImage: "tag")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tag-management")
            }
            .frame(width: ExerciseToolbarStyle.targetSize * (activeExercise == nil ? 2 : 3),
                   height: ExerciseToolbarStyle.targetSize, alignment: .trailing)
            .glassEffect(.regular, in: Capsule())
            .glassEffectID("exercise-actions", in: toolbarGlass)
            .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: activeExercise != nil)
            .frame(width: ExerciseToolbarStyle.targetSize * 3, alignment: .trailing)
        }
    }

    var filteredExercises: [WorkoutExercise] {
        guard let tagIDs = displayedFilter else { return allExercises }
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
                .task(id: FilterChange(tags: displayedFilter,
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
                        showsEmptyMessage: filteredExercises.isEmpty && displayedFilter != nil)
                        .allowsHitTesting(false)
                }
                .background { DefaultScreenBackground().ignoresSafeArea() }
                .navigationTitle(pageTitle)
                .navigationBarTitleDisplayMode(.large)
                .onChange(of: groups.map(\.persistentModelID), initial: true) { _, ids in
                    if let selected = navigation.selectedGroup, !ids.contains(selected.persistentModelID) {
                        navigation.selectedGroup = nil
                    }
                }
                .onDisappear {
                    filterTransition.cancel()
                    displayedFilterChange = nil
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        exerciseToolbarActions
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddExerciseSheet = true }) {
                            Label("Add Exercise", systemImage: "plus")
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
                .navigationDestination(isPresented: $showingTagManagement) {
                    TagManagementView()
                }
            }
        }
        .overlay {
            if !showingTagManagement, !groups.isEmpty {
                DockableTagWheel(groups: groups, selection: groupSelection)
            }
        }
    }

    private func transitionFilter() {
        let change = filterChange
        guard displayedFilterChange != nil, !reduceMotion, change.reveal == nil else {
            filterTransition.cancel()
            withoutFilterAnimation {
                displayedFilterChange = change
            }
            return
        }
        guard displayedFilter != change.tags else { return }
        filterTransition.begin()
        withoutFilterAnimation {
            displayedFilterChange = change
        }
    }

    private func withoutFilterAnimation(_ update: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, update)
    }

    private struct FilterChange: Equatable {
        let tags: Set<PersistentIdentifier>?
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

import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(ExerciseBackgroundStore.self) private var background
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutExercise.title) private var allExercises: [WorkoutExercise]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @State private var showingBackgroundSheet = false
    @State private var showingAddExerciseSheet = false
    @State private var showingAddTagSheet = false
    @State private var editingTag: Tag?
    @State private var tagPendingDeletion: Tag?
    
    @State var navigation = ExerciseNavigation()
    @State private var highlightedRequest: ExerciseRevealRequest?
    @State private var revealPosition: ExerciseRevealPosition?
    @State private var viewportSize: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var backgroundTagColors: [String] {
        allTags.filter { navigation.selectedTagIDs.contains($0.persistentModelID) }.map(\.colorHex)
    }
    
    var filteredExercises: [WorkoutExercise] {
        if navigation.selectedTagIDs.isEmpty {
            return allExercises
        }
        return allExercises.filter { exercise in
            exercise.tags.contains { tag in
                navigation.selectedTagIDs.contains(tag.persistentModelID)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    tagBar
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

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
                .task(id: navigation.revealRequest) {
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
                .background { ScreenBackgroundView(background: background, tagColors: backgroundTagColors).ignoresSafeArea() }
                .navigationTitle("All Exercises")
                .navigationBarTitleDisplayMode(.large)
                .onChange(of: allTags.map(\.persistentModelID)) { _, ids in
                    navigation.selectedTagIDs.formIntersection(ids)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Customize Background", systemImage: "paintpalette") { showingBackgroundSheet = true }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ResetCompletedExercisesButton(exercises: allExercises)
                    }
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
                .sheet(isPresented: $showingBackgroundSheet) {
                    BackgroundCustomizationSheet(background: background, title: "Exercises Background", tagColors: backgroundTagColors)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
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
    }
    
    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 12) {
                    ForEach(allTags) { tag in
                        let isSelected = navigation.selectedTagIDs.contains(tag.persistentModelID)
                        Button {
                            withAnimation(.smooth) {
                                if isSelected {
                                    navigation.selectedTagIDs.remove(tag.persistentModelID)
                                } else {
                                    navigation.selectedTagIDs.insert(tag.persistentModelID)
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
                        .contentShape(.contextMenuPreview, Capsule())
                        .contextMenu {
                            Button {
                                editingTag = tag
                            } label: {
                                Label("Edit Tag", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                tagPendingDeletion = tag
                            } label: {
                                Label("Delete Tag", systemImage: "trash")
                            }
                        }
                        .accessibilityAction(named: "Edit Tag") { editingTag = tag }
                        .accessibilityAction(named: "Delete Tag") { tagPendingDeletion = tag }
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

import SwiftUI
import SwiftData

struct EditExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: WorkoutExercise
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Title", text: $exercise.title)
                        .subtleFormRowShadow(.first)
                    TextField("Subtitle (Optional)", text: $exercise.subtitle)
                        .subtleFormRowShadow(.middle)
                    TextField("Details (Optional)", text: $exercise.details)
                        .subtleFormRowShadow(.last)
                }
                
                Section(header: Text("Targets")) {
                    Stepper("Sets: \(exercise.numberOfSets)", value: $exercise.numberOfSets, in: 1...20)
                        .subtleFormRowShadow(.first)
                    Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...100)
                        .subtleFormRowShadow(.last)
                }
                
                if !allTags.isEmpty {
                    Section(header: Text("Tags")) {
                        ExerciseTagLayout() {
                            ForEach(allTags) { tag in
                                Button {
                                    if let index = exercise.tags.firstIndex(of: tag) {
                                        exercise.tags.remove(at: index)
                                    } else {
                                        exercise.tags.append(tag)
                                    }
                                } label: {
                                    TagSelectionLabel(tag: tag, isSelected: exercise.tags.contains(tag), wrapsName: true)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                        .subtleFormRowShadow()
                    }
                }
            }
            .transparentNavigationChrome()
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(exercise.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private struct ExerciseTagLayout: Layout {
    private let spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let frames = frames(for: subviews, width: width)
        return CGSize(width: width.isFinite ? width : (frames.last?.maxX ?? 0),
                      height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(for: subviews, width: bounds.width)) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }

    private func frames(for subviews: Subviews, width: CGFloat) -> [CGRect] {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        return subviews.map { subview in
            let ideal = subview.sizeThatFits(.unspecified)
            let size = ideal.width > width
                ? subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
                : ideal
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            let frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            return frame
        }
    }
}

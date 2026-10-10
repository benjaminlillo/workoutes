import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ExerciseCompletion.completedAt, order: .reverse),
                  SortDescriptor(\ExerciseCompletion.id)]) private var completions: [ExerciseCompletion]
    @State private var deletionError: String?

    var body: some View {
        List {
            ForEach(Array(completions.enumerated()), id: \.element.id) { index, completion in
                VStack(alignment: .leading, spacing: 4) {
                    Text(completion.exerciseTitle)
                        .font(.headline)
                    Text(completion.completedAt, format: .dateTime.year().month(.abbreviated).day().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .subtleFormRowBorder(.row(at: index, count: completions.count))
            }
            .onDelete(perform: deleteEntries)
        }
        .overlay {
            if completions.isEmpty {
                ContentUnavailableView("No Exercise History", systemImage: "clock.arrow.circlepath",
                                       description: Text("Completed exercises will appear here."))
            }
        }
        .transparentNavigationChrome()
        .defaultScreenBackground()
        .navigationTitle("Exercise History")
        .toolbar {
            if !completions.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
        .alert("Delete Failed", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "")
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        let entries = offsets.map { completions[$0] }
        do {
            try ExerciseHistory.delete(entries, in: modelContext)
        } catch {
            deletionError = error.localizedDescription
        }
    }
}

@MainActor
enum ExerciseHistory {
    static func delete(_ entries: [ExerciseCompletion], in context: ModelContext) throws {
        // Preserve any pending edits before starting the deletion transaction.
        try context.save()
        for entry in entries {
            context.delete(entry)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseHistoryView()
    }
    .modelContainer(for: ExerciseCompletion.self, inMemory: true)
}

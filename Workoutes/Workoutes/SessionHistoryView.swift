import SwiftData
import SwiftUI

struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingSession.startedAt, order: .reverse) private var sessions: [TrainingSession]
    @State private var pendingDeletion: TrainingSession?

    private var completedSessions: [TrainingSession] { sessions.filter { $0.endedAt != nil } }

    var body: some View {
        NavigationStack {
            List {
                if completedSessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "figure.run",
                        description: Text("Completed and stopped sessions will appear here.")
                    )
                } else {
                    ForEach(completedSessions) { session in
                        NavigationLink {
                            SessionHistoryDetailView(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(session.startedAt, format: .dateTime.month().day().year().hour().minute())
                                        .font(.headline)
                                    Spacer()
                                    Text(duration(session))
                                        .font(.subheadline.monospacedDigit())
                                }
                                Text(session.endedEarly ? "Ended Early" : "Completed")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(session.endedEarly ? .orange : .green)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash") {
                                pendingDeletion = session
                            }
                            .tint(.red)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .alert("Delete Session?", isPresented: Binding(
                get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
            ), presenting: pendingDeletion) { session in
                Button("Delete", role: .destructive) {
                    pendingDeletion = nil
                    deleteAfterAlertDismisses(session)
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { _ in
                Text("This session and its recorded block times will be permanently deleted.")
            }
        }
    }

    private func duration(_ session: TrainingSession) -> String {
        formatDuration((session.endedAt ?? .now).timeIntervalSince(session.startedAt))
    }

    private func deleteAfterAlertDismisses(_ session: TrainingSession) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.smooth(duration: 0.3)) {
                modelContext.delete(session)
            }
            try? modelContext.save()
        }
    }
}

struct SessionHistoryDetailView: View {
    let session: TrainingSession

    private var orderedBlocks: [SessionBlockRecord] {
        session.blocks.sorted { $0.order < $1.order }
    }

    private var executionGroups: [SessionExecutionGroup] {
        var result: [SessionExecutionGroup] = []
        for block in orderedBlocks {
            if let groupID = block.exerciseGroupID,
               let last = result.indices.last,
               result[last].groupID == groupID {
                result[last].blocks.append(block)
            } else {
                result.append(SessionExecutionGroup(
                    id: block.exerciseGroupID ?? block.id,
                    groupID: block.exerciseGroupID,
                    title: block.exerciseGroupID == nil ? nil : block.exerciseTitle,
                    blocks: [block]
                ))
            }
        }
        return result
    }

    var body: some View {
        List {
            Section("Session") {
                LabeledContent("Started", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Total", value: formatDuration((session.endedAt ?? .now).timeIntervalSince(session.startedAt)))
                LabeledContent("Result", value: session.endedEarly ? "Ended Early" : "Completed")
            }
            if session.templateSnapshot.isEmpty {
                Section("Template Snapshot") {
                    ForEach(orderedBlocks) { block in
                        legacyBlockRow(block)
                    }
                }
            } else {
                Section("Template Snapshot") {
                    ForEach(session.templateSnapshot.sorted { $0.order < $1.order }) { block in
                        HStack {
                            Label(block.name, systemImage: block.kind == .exercise ? "figure.strengthtraining.traditional" : "timer")
                            Spacer()
                            Text(block.kind == .exercise
                                 ? "\(formatDuration(block.duration)) between sets"
                                 : formatDuration(block.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Execution") {
                    ForEach(executionGroups) { group in
                        VStack(alignment: .leading, spacing: 9) {
                            if let title = group.title {
                                Text(title)
                                    .font(.headline)
                            }
                            ForEach(group.blocks) { block in
                                executionBlockRow(block)
                                if block.id != group.blocks.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle("Session Details")
    }

    @ViewBuilder
    private func legacyBlockRow(_ block: SessionBlockRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(block.resolvedName ?? block.configuredName,
                      systemImage: block.kind == .exercise ? "figure.strengthtraining.traditional" : "timer")
                Spacer()
                measuredTime(for: block)
            }
            if block.resolvedName != nil && block.resolvedName != block.configuredName {
                Text("Template: \(block.configuredName)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if block.kind == .rest {
                Text("Planned: \(formatDuration(block.plannedRestDuration))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func executionBlockRow(_ block: SessionBlockRecord) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Label(executionTitle(for: block), systemImage: block.kind == .exercise ? "figure.strengthtraining.traditional" : "timer")
            Spacer()
            measuredTime(for: block)
        }
        if block.kind == .rest {
            Text("Planned: \(formatDuration(block.plannedRestDuration))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func executionTitle(for block: SessionBlockRecord) -> String {
        if let setIndex = block.setIndex { return "Set \(setIndex)" }
        if block.isInterSetRest { return "Rest" }
        return block.resolvedName ?? block.configuredName
    }

    @ViewBuilder
    private func measuredTime(for block: SessionBlockRecord) -> some View {
        if let measured = block.measuredDuration {
            Text(formatDuration(measured)).monospacedDigit()
        } else {
            Text("Not reached").foregroundStyle(.secondary)
        }
    }
}

private struct SessionExecutionGroup: Identifiable {
    let id: UUID
    let groupID: UUID?
    let title: String?
    var blocks: [SessionBlockRecord]
}

private func formatDuration(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval.rounded(.down)))
    let hours = seconds / 3600
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, (seconds % 3600) / 60, seconds % 60)
        : String(format: "%d:%02d", seconds / 60, seconds % 60)
}

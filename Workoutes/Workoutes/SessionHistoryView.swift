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
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDeletion = session
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .confirmationDialog("Delete Session?", isPresented: Binding(
                get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let pendingDeletion { modelContext.delete(pendingDeletion) }
                    try? modelContext.save()
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("This session and its recorded block times will be permanently deleted.")
            }
        }
    }

    private func duration(_ session: TrainingSession) -> String {
        formatDuration((session.endedAt ?? .now).timeIntervalSince(session.startedAt))
    }
}

struct SessionHistoryDetailView: View {
    let session: TrainingSession

    var body: some View {
        List {
            Section("Session") {
                LabeledContent("Started", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Total", value: formatDuration((session.endedAt ?? .now).timeIntervalSince(session.startedAt)))
                LabeledContent("Result", value: session.endedEarly ? "Ended Early" : "Completed")
            }
            Section("Template Snapshot") {
                ForEach(session.blocks.sorted { $0.order < $1.order }) { block in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(block.resolvedName ?? block.configuredName,
                                  systemImage: block.kind == .exercise ? "figure.strengthtraining.traditional" : "timer")
                            Spacer()
                            if let measured = block.measuredDuration {
                                Text(formatDuration(measured)).monospacedDigit()
                            } else {
                                Text("Not reached").foregroundStyle(.secondary)
                            }
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
            }
        }
        .navigationTitle("Session Details")
    }
}

private func formatDuration(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval.rounded(.down)))
    let hours = seconds / 3600
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, (seconds % 3600) / 60, seconds % 60)
        : String(format: "%d:%02d", seconds / 60, seconds % 60)
}

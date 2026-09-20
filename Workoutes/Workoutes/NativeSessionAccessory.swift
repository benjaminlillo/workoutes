import SwiftUI

struct NativeSessionAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    let content: SessionActivityAttributes.ContentState?
    let isUpdating: Bool
    let onStart: () -> Void
    let onAdvance: () -> Void

    private var isCompact: Bool { placement == .inline }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: isCompact ? 8 : 14) {
                VStack(alignment: .leading, spacing: isCompact ? 1 : 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(content?.blockName ?? "No Active Session")
                            .font(isCompact ? .caption.weight(.semibold) : .body.weight(.semibold))
                            .lineLimit(1)

                        if let content {
                            Text(blockTime(for: content, at: context.date))
                                .font(isCompact ? .caption.bold().monospacedDigit() : .title3.bold().monospacedDigit())
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    if isCompact, let content {
                        Text("Total \(elapsed(from: content.sessionStartedAt, at: context.date))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                if !isCompact, let content {
                    Text("Total \(elapsed(from: content.sessionStartedAt, at: context.date))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Button(action: content == nil ? onStart : onAdvance) {
                    Image(systemName: actionIcon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isUpdating)
                .accessibilityLabel(actionLabel)
            }
            .padding(.leading, isCompact ? 14 : 18)
            .padding(.trailing, isCompact ? 6 : 10)
            .padding(.vertical, isCompact ? 4 : 8)
            .frame(minHeight: isCompact ? 48 : 62)
        }
    }

    private var actionIcon: String {
        guard let content else { return "play.fill" }
        return content.isLastBlock ? "checkmark" : "forward.end.fill"
    }

    private var actionLabel: String {
        guard let content else { return "Start Session" }
        return content.isLastBlock ? "Finish Session" : "Next Block"
    }

    private func blockTime(for content: SessionActivityAttributes.ContentState, at date: Date) -> String {
        if let end = content.restEndsAt {
            let remaining = end.timeIntervalSince(date)
            return (remaining < 0 ? "+" : "") + duration(abs(remaining))
        }
        return elapsed(from: content.blockStartedAt, at: date)
    }

    private func elapsed(from start: Date, at date: Date) -> String {
        duration(max(0, date.timeIntervalSince(start)))
    }

    private func duration(_ value: TimeInterval) -> String {
        let seconds = Int(value.rounded(.down))
        let hours = seconds / 3600
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, (seconds % 3600) / 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

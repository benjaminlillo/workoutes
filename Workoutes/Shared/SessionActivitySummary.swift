import AppIntents
import SwiftUI

struct SessionActivitySummary: View {
    let state: SessionActivityAttributes.ContentState
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 14) {
            VStack(alignment: .leading, spacing: compact ? 1 : 4) {
                Text(state.blockName)
                    .font(compact ? .caption.weight(.semibold) : .headline)
                    .lineLimit(1)
                SessionCurrentTimeText(state: state, compact: compact)
                    .font(compact ? .headline.monospacedDigit() : .system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                if !compact {
                    HStack(spacing: 5) {
                        Text("Session").foregroundStyle(.secondary)
                        Text(timerInterval: state.sessionStartedAt...Date.distantFuture, countsDown: false).monospacedDigit()
                    }
                    .font(.caption)
                }
            }
            Spacer(minLength: 4)
            if !state.ended {
                Button(intent: SessionLiveActivityIntent(sessionID: state.sessionID, blockID: state.blockID)) {
                    Image(systemName: state.isLastBlock ? "checkmark" : "forward.end.fill")
                        .font(compact ? .body.weight(.semibold) : .title3.weight(.semibold))
                        .frame(width: compact ? 32 : 44, height: compact ? 32 : 44)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(color(hex: state.accentColorHex))
                .accessibilityLabel(state.isLastBlock ? "Finish Session" : "Next Block")
            }
        }
        .foregroundStyle(.white)
    }

    private func color(hex: String) -> Color {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let value = UInt64(clean, radix: 16) else { return .mint }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

struct SessionCurrentTimeText: View {
    let state: SessionActivityAttributes.ContentState
    var compact = false

    var body: some View {
        if state.blockKind == .rest, let end = state.restEndsAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(format(remaining: end.timeIntervalSince(context.date)))
            }
        } else {
            Text(timerInterval: state.blockStartedAt...Date.distantFuture, countsDown: false)
        }
    }

    private func format(remaining: TimeInterval) -> String {
        let value = Int(abs(remaining).rounded(.down))
        let hours = value / 3600
        let text = hours > 0
            ? String(format: "%d:%02d:%02d", hours, (value % 3600) / 60, value % 60)
            : String(format: "%d:%02d", value / 60, value % 60)
        return remaining < 0 ? "+\(text)" : text
    }
}

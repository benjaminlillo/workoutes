import SwiftUI

struct ExerciseStatusSymbol: View {
    let status: ExerciseStatus
    let accentColor: Color
    var cancellationWindow: DateInterval? = nil

    var body: some View {
        ZStack {
            Circle().fill(status == .done ? accentColor : .clear)
            if status == .playing, let cancellationWindow {
                ExerciseCancellationRing(window: cancellationWindow, accentColor: accentColor)
                    .id(cancellationWindow)
            } else {
                Circle().strokeBorder(status == .empty ? .gray : accentColor, lineWidth: 2)
            }
            if status == .done {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            } else if status == .playing {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
        }
        .frame(width: 28, height: 28)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
}

private struct ExerciseCancellationRing: View {
    let window: DateInterval
    let accentColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var finished = false

    private static let segmentCount = 10
    private static let lineWidth: CGFloat = 2
    private static let mergeDuration: TimeInterval = 1

    var body: some View {
        if finished || window.end <= .now {
            Circle().strokeBorder(accentColor, lineWidth: Self.lineWidth)
        } else {
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(window.start))
                if elapsed >= window.duration {
                    Circle().strokeBorder(accentColor, lineWidth: Self.lineWidth)
                } else {
                    segments(elapsed: elapsed)
                }
            }
            .task {
                let remaining = max(0, window.end.timeIntervalSinceNow)
                do { try await Task.sleep(for: .seconds(remaining)) }
                catch { return }
                finished = true
            }
        }
    }

    private func segments(elapsed: TimeInterval) -> some View {
        let fill = elapsed / window.duration * Double(Self.segmentCount)
        let merge = 1 - min(1, (window.duration - elapsed) / Self.mergeDuration)
        let easedMerge = merge * merge * (3 - 2 * merge)
        let halfGap = 8 * (1 - easedMerge)
        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = (min(size.width, size.height) - Self.lineWidth) / 2
            guard radius > 0 else { return }

            let segmentAngle = 360.0 / Double(Self.segmentCount)
            for index in 0..<Self.segmentCount {
                let start = -90 + Double(index) * segmentAngle
                var arc = Path()
                arc.addArc(center: center, radius: radius, startAngle: .degrees(start + halfGap),
                           endAngle: .degrees(start + segmentAngle - halfGap), clockwise: false)
                let coverage = min(max(fill - Double(index), 0), 1)
                context.stroke(arc, with: .color(accentColor.opacity(0.28 + 0.72 * coverage)),
                               style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
            }
        }
    }
}

import SwiftUI

enum ExerciseCardStyle {
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }
}

/// The same card surface is used on screen and inside expanded Live Activities.
struct ExerciseCardSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(ExerciseCardStyle.shape)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

struct ExerciseCardMetrics<Weight: View, Sets: View, Repetitions: View>: View {
    @ViewBuilder var weight: () -> Weight
    @ViewBuilder var sets: () -> Sets
    @ViewBuilder var repetitions: () -> Repetitions

    var body: some View {
        HStack(spacing: 0) {
            weight()
            metricDivider
            sets()
            metricDivider
            repetitions()
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1, height: 42)
    }
}

struct ExerciseQueuedSymbol: View {
    let accentColor: Color

    var body: some View {
        Image(systemName: "clock.arrow.circlepath")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(accentColor)
            .frame(width: 44, height: 44)
    }
}

struct ExerciseQueuedLabel: View {
    let number: Int?
    let accentColor: Color

    var body: some View {
        Label {
            if let number {
                Text("Queued · Exercise \(number)")
            } else {
                Text("Up Next")
            }
        } icon: {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(accentColor)
    }
}

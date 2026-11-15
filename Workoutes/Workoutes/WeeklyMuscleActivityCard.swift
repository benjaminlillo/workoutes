import SwiftUI

struct WeeklyMuscleActivityCard: View {
    private let activity: WeeklyMuscleActivity

    init(summary: WeeklySummary, distribution: WeeklyTagDistribution? = nil) {
        activity = WeeklyMuscleActivity(distribution: distribution ?? WeeklyTagDistribution(summary: summary))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Muscle Activity").font(.title3.bold())
            WeeklyMuscleDiagram(activity: activity)
        }
        .padding(20)
        .statisticCardBackground()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Muscle Activity")
        .accessibilityValue(accessibilitySummary)
        .accessibilityIdentifier("weeklyMuscleActivity")
    }

    private var accessibilitySummary: String {
        let names = activity.entries.filter { $0.icon != nil }.map(\.name)
        return names.isEmpty ? String(localized: "No muscle areas recorded") : names.joined(separator: ", ")
    }
}

private struct WeeklyMuscleDiagram: View {
    let activity: WeeklyMuscleActivity
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            ForEach(MuscleBodySide.allCases, id: \.self) { side in
                let frame = MuscleBodyLayout.frame(for: side, in: geometry.size)
                Image(uiImage: MuscleBodyImageCache.shared.image(side: side, activity: activity,
                    size: frame.size, scale: displayScale, isDark: colorScheme == .dark))
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .frame(height: MuscleBodyLayout.height)
        .accessibilityHidden(true)
    }
}

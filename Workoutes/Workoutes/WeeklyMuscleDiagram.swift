import SwiftUI

struct WeeklyMuscleDiagram: View {
    let activity: WeeklyMuscleActivity
    var maximumHeight = MuscleBodyLayout.height
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            ForEach(MuscleBodySide.allCases, id: \.self) { side in
                let frame = MuscleBodyLayout.frame(for: side, in: geometry.size, maximumHeight: maximumHeight)
                Image(uiImage: MuscleBodyImageCache.shared.image(side: side, activity: activity,
                    size: frame.size, scale: displayScale, isDark: colorScheme == .dark))
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .accessibilityHidden(true)
    }
}

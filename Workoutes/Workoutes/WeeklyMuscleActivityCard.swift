import SwiftUI

struct WeeklyMuscleActivityCard: View {
    private let activity: WeeklyMuscleActivity

    init(summary: WeeklySummary, distribution: WeeklyTagDistribution? = nil) {
        activity = WeeklyMuscleActivity(distribution: distribution ?? WeeklyTagDistribution(summary: summary))
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Muscle Activity").font(.title3.bold())
            WeeklyMuscleDiagram(activity: activity)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            if activity.entries.isEmpty {
                Text("No completed exercises")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                Divider()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .topLeading),
                                         count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                          alignment: .leading, spacing: 12) {
                    ForEach(activity.entries) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Circle().fill(color(for: entry)).frame(width: 7, height: 7)
                                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
                                .accessibilityHidden(true)
                            Text(entry.name).font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(entry.count, format: .number)
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(color(for: entry))
                                .fixedSize()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(entry.name)
                        .accessibilityValue("\(entry.count) completed exercises")
                    }
                }
            }
        }
        .padding(20)
        .statisticCardBackground()
        .accessibilityIdentifier("weeklyMuscleActivity")
    }
}

private func color(for entry: WeeklyMuscleActivity.Entry) -> Color {
    entry.colorHex.map { Color(hex: $0) } ?? .gray
}

private struct WeeklyMuscleDiagram: View {
    let activity: WeeklyMuscleActivity
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .caption) private var badgeHeight: CGFloat = 26

    private var calloutCount: Int {
        MuscleBodySide.allCases.map { activity.callouts(on: $0).count }.max() ?? 0
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Front").frame(maxWidth: .infinity)
                Text("Back").frame(maxWidth: .infinity)
            }
            .font(.caption).foregroundStyle(.secondary)
            GeometryReader { geometry in
                let style = MuscleDiagramStyle(colorScheme: colorScheme, contrast: contrast,
                    dynamicTypeSize: dynamicTypeSize, locale: locale, scale: displayScale)
                if let image = MuscleDiagramImageCache.shared.image(activity: activity, size: geometry.size,
                    badgeHeight: badgeHeight, style: style, content: {
                        MuscleDiagramDrawing(activity: activity, badgeHeight: badgeHeight, background: style.background)
                    }) {
                    Image(uiImage: image).resizable()
                } else {
                    MuscleDiagramDrawing(activity: activity, badgeHeight: badgeHeight, background: style.background)
                }
            }
            .frame(height: max(280, CGFloat(calloutCount) * (badgeHeight + 8)))
        }
        // The legend exposes every tag once, with its full name and count.
        .accessibilityHidden(true)
    }
}

/// Also used as the fallback if a snapshot cannot be created.
struct MuscleDiagramDrawing: View {
    let activity: WeeklyMuscleActivity
    let badgeHeight: CGFloat
    var background: Color = Color(uiColor: .secondarySystemGroupedBackground)
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let bodyHeight = min(320, geometry.size.width * 0.86, geometry.size.height)
            ZStack(alignment: .topLeading) {
                ForEach(MuscleBodySide.allCases, id: \.self) { side in
                    let frame = bodyFrame(side, size: geometry.size, bodyHeight: bodyHeight)
                    Image(uiImage: MuscleBodyImageCache.shared.image(side: side, activity: activity,
                        size: frame.size, scale: displayScale, isDark: colorScheme == .dark))
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                    callouts(side, frame: frame, size: geometry.size, spacing: badgeHeight + 8)
                }
            }
        }
    }

    private func bodyFrame(_ side: MuscleBodySide, size: CGSize, bodyHeight: CGFloat) -> CGRect {
        let center = size.width * (side == .front ? 0.27 : 0.73)
        return CGRect(x: center - bodyHeight / 4, y: (size.height - bodyHeight) / 2,
                      width: bodyHeight / 2, height: bodyHeight)
    }

    private func callouts(_ side: MuscleBodySide, frame: CGRect, size: CGSize, spacing: CGFloat) -> some View {
        let entries = activity.callouts(on: side)
        let targets = entries.map { entry in
            let anchor = MuscleBodyAnatomy.anchor(for: entry.icon!).point
            return CGPoint(x: frame.minX + anchor.x * frame.width, y: frame.minY + anchor.y * frame.height)
        }
        let positions = MuscleCalloutLayout.positions(targets: targets.map(\.y), height: size.height, spacing: spacing)
        return ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            let target = targets[index]
            let badgeWidth = max(28, badgeHeight * (entry.count >= 100 ? 1.8 : 1.3))
            let badgeX = side == .front ? badgeWidth / 2 : size.width - badgeWidth / 2
            let labelY = positions[index]
            let lineStart = CGPoint(x: badgeX + (side == .front ? badgeWidth / 2 : -badgeWidth / 2), y: labelY)
            Path { path in
                path.move(to: lineStart)
                path.addLine(to: CGPoint(x: (lineStart.x + target.x) / 2, y: labelY))
                path.addLine(to: target)
            }
            .stroke(color(for: entry).opacity(0.85), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            Circle().fill(color(for: entry)).frame(width: 4, height: 4).position(target)
            Text(entry.count, format: .number)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(color(for: entry))
                .frame(width: badgeWidth, height: badgeHeight)
                .background(background, in: RoundedRectangle(cornerRadius: 9))
                .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(color(for: entry).opacity(0.4), lineWidth: 1) }
                .position(x: badgeX, y: labelY)
        }
    }
}

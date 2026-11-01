import SwiftUI

struct WeeklyMuscleActivityCard: View {
    let summary: WeeklySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let activity = WeeklyMuscleActivity(summary: summary)
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
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .subtleCardShadow()
        .accessibilityIdentifier("weeklyMuscleActivity")
    }
}

private func color(for entry: WeeklyMuscleActivity.Entry) -> Color {
    entry.colorHex.map { Color(hex: $0) } ?? .gray
}

private struct WeeklyMuscleDiagram: View {
    let activity: WeeklyMuscleActivity
    @Environment(\.colorScheme) private var colorScheme
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
                let bodyHeight = min(320, geometry.size.width * 0.86, geometry.size.height)
                let spacing = badgeHeight + 8
                let height = geometry.size.height
                ZStack(alignment: .topLeading) {
                    ForEach(MuscleBodySide.allCases, id: \.self) { side in
                        let frame = bodyFrame(side, size: CGSize(width: geometry.size.width, height: height), bodyHeight: bodyHeight)
                        bodyImage(side)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                        callouts(side, frame: frame, size: CGSize(width: geometry.size.width, height: height), spacing: spacing)
                    }
                }
            }
            .frame(height: max(280, CGFloat(calloutCount) * (badgeHeight + 8)))
        }
        // The legend exposes every tag once, with its full name and count.
        .accessibilityHidden(true)
    }

    private func bodyFrame(_ side: MuscleBodySide, size: CGSize, bodyHeight: CGFloat) -> CGRect {
        let center = size.width * (side == .front ? 0.27 : 0.73)
        return CGRect(x: center - bodyHeight / 4, y: (size.height - bodyHeight) / 2,
                      width: bodyHeight / 2, height: bodyHeight)
    }

    private func bodyImage(_ side: MuscleBodySide) -> some View {
        ZStack {
            Image(side.asset("base"))
                .resizable().scaledToFit()
                .foregroundStyle(Color(white: colorScheme == .dark ? 0.30 : 0.84))
            ForEach(side.regions, id: \.self) { region in
                let entries = activity.entries(for: region, on: side)
                if !entries.isEmpty {
                    Image(side.asset(region))
                        .resizable().scaledToFit()
                        .foregroundStyle(regionGradient(entries))
                }
            }
        }
    }

    /// Distinct bands preserve each tag's color when specific and broad tags overlap.
    private func regionGradient(_ entries: [WeeklyMuscleActivity.Entry]) -> LinearGradient {
        let colors = entries.map { color(for: $0) }
        let stops = colors.enumerated().flatMap { index, color in
            [Gradient.Stop(color: color, location: Double(index) / Double(colors.count)),
             Gradient.Stop(color: color, location: Double(index + 1) / Double(colors.count))]
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
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
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 9))
                .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(color(for: entry).opacity(0.4), lineWidth: 1) }
                .position(x: badgeX, y: labelY)
        }
    }
}

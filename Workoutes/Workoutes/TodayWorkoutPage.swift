import SwiftData
import SwiftUI

struct TodayWorkoutPage: View {
    let completions: [ExerciseCompletion]
    let week: DateInterval
    let isVisible: Bool

    @Query(sort: \TagGroup.name) private var groups: [TagGroup]
    @AppStorage(NextWorkoutNoteButton.storageKey) private var note = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 44
    @State private var revealed = false
    @State private var showsGroups = false

    var body: some View {
        let pending = Self.pendingGroups(groups, completions: completions, week: week)
        let noteText = note.trimmingCharacters(in: .whitespacesAndNewlines)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "Workouts")
                    .font(.system(size: titleSize, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if !pending.isEmpty {
                    Text("To Train This Week")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if pending.isEmpty {
                Text(groups.isEmpty ? LocalizedStringResource("No Groups") : "All Groups Trained")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cloud(pending)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !noteText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next Workout Note").font(.headline)
                    Text(noteText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .statisticCardBackground(cornerRadius: 24)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("todayWorkoutNote")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .task(id: isVisible && scenePhase == .active) {
            guard isVisible, scenePhase == .active, !revealed else { return }
            if !reduceMotion {
                // Give the system's launch fade time to reveal the Home background.
                try? await Task.sleep(for: .milliseconds(240))
            }
            guard !Task.isCancelled else { return }
            revealed = true
        }
    }

    static func pendingGroups(_ groups: [TagGroup], completions: [ExerciseCompletion], week: DateInterval) -> [TagGroup] {
        let trainedTagIDs = Set(completions.lazy
            .filter { $0.completedAt >= week.start && $0.completedAt < week.end }
            .flatMap { $0.exercise?.tags ?? [] }
            .map(\.persistentModelID))
        return groups.filter { $0.tagIDs.isDisjoint(with: trainedTagIDs) }
    }

    private func cloud(_ groups: [TagGroup]) -> some View {
        ViewThatFits(in: .vertical) {
            PendingGroupCloudLayout {
                PendingGroupCloudTexture()
                ForEach(Array(groups.enumerated()), id: \.element.stableID) { index, group in
                    pill(group)
                        .compositingGroup()
                        .opacity(revealed || reduceMotion ? 1 : 0)
                        .offset(y: revealed || reduceMotion ? 0 : 8)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.28).delay(Double(min(index, 12)) * 0.035),
                                   value: revealed)
                }
            }

            // Keep names readable on compact screens or with a large custom catalog.
            Button { showsGroups = true } label: {
                Text("Pending Groups")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .sheet(isPresented: $showsGroups) {
            NavigationStack {
                List(groups) { group in
                    HStack(spacing: 8) {
                        ExerciseGroupIcon(group: group)
                        Text(group.name)
                    }
                }
                .navigationTitle("To Train This Week")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showsGroups = false }
                    }
                }
            }
        }
    }

    private func pill(_ group: TagGroup) -> some View {
        HStack(spacing: 8) {
            ExerciseGroupIcon(group: group)
            Text(group.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minHeight: 52)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

private struct PendingGroupCloudTexture: View {
    @AppStorage("appAccentColor") private var accentColorRawValue = ThemeColor.indigo.rawValue
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tint = Color(hex: ThemeColor.resolve(accentColorRawValue).hex(for: colorScheme))
        let strength = colorScheme == .dark ? 0.32 : 0.22
        Canvas { context, size in
            let spacing: CGFloat = 9
            let diameter: CGFloat = 1.6
            let startX = size.width.truncatingRemainder(dividingBy: spacing) / 2
            let startY = size.height.truncatingRemainder(dividingBy: spacing) / 2
            var dots = Path()
            for y in stride(from: startY, to: size.height, by: spacing) {
                for x in stride(from: startX, to: size.width, by: spacing) {
                    dots.addEllipse(in: CGRect(x: x - diameter / 2, y: y - diameter / 2,
                                               width: diameter, height: diameter))
                }
            }

            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .style(EllipticalGradient(colors: [tint.opacity(strength * 0.16), tint.opacity(0)])))
            context.fill(dots, with: .style(EllipticalGradient(stops: [
                .init(color: tint.opacity(strength), location: 0),
                .init(color: tint.opacity(strength * 0.75), location: 0.46),
                .init(color: tint.opacity(strength * 0.18), location: 0.82),
                .init(color: tint.opacity(0), location: 1)
            ])))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PendingGroupCloudLayout: Layout {
    private let spacing: CGFloat = 10
    private let anchors: [CGFloat] = [0.63, 0.17, 0.85, 0.40, 0.13, 0.74, 0.30, 0.81]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.dropFirst().map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let sizes = sizes(in: width, subviews: subviews)
        let minimumHeight = height(of: packedRows(sizes, width: width), sizes: sizes)
        return CGSize(width: width, height: max(proposal.height ?? 0, minimumHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let texture = subviews.first, subviews.count > 1 else { return }
        let sizes = sizes(in: bounds.width, subviews: subviews)
        var rows = packedRows(sizes, width: bounds.width)
        var usedHeight = height(of: rows, sizes: sizes)

        // Unpack pairs when there is room to scatter more pills down the page.
        for row in rows.indices.reversed() where rows[row].count == 2 {
            let extraHeight = min(sizes[rows[row][0]].height, sizes[rows[row][1]].height) + spacing
            if usedHeight + extraHeight <= bounds.height {
                let second = rows[row].removeLast()
                rows.insert([second], at: row + 1)
                usedHeight += extraHeight
            }
        }

        let freeHeight = max(0, bounds.height - usedHeight)
        let extraGap = min(10, freeHeight / CGFloat(rows.count + 1))
        var y = bounds.minY + (freeHeight - extraGap * CGFloat(max(0, rows.count - 1))) / 2
        var pillBounds = CGRect.null

        for (rowIndex, row) in rows.enumerated() {
            let rowHeight = row.map { sizes[$0].height }.max() ?? 0
            let rowWidth = row.reduce(0) { $0 + sizes[$1].width } + spacing * CGFloat(row.count - 1)
            let slack = max(0, bounds.width - rowWidth)
            var x = bounds.minX + slack * anchors[rowIndex % anchors.count]
            for index in row {
                let size = sizes[index]
                let origin = CGPoint(x: x, y: y + (rowHeight - size.height) / 2)
                subviews[index + 1].place(at: origin, anchor: .topLeading, proposal: ProposedViewSize(size))
                pillBounds = pillBounds.union(CGRect(origin: origin, size: size))
                x += size.width + spacing
            }
            y += rowHeight + spacing + extraGap
        }

        let textureBounds = pillBounds.insetBy(dx: -38, dy: -38).intersection(bounds)
        texture.place(at: textureBounds.origin, anchor: .topLeading, proposal: ProposedViewSize(textureBounds.size))
    }

    private func sizes(in width: CGFloat, subviews: Subviews) -> [CGSize] {
        // The first subview is the texture. Only the capsules contribute to the layout's size.
        subviews.dropFirst().map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
    }

    private func packedRows(_ sizes: [CGSize], width: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        for index in sizes.indices {
            if let last = rows.last, last.count == 1, sizes[last[0]].width + sizes[index].width + spacing <= width {
                rows[rows.count - 1].append(index)
            } else {
                rows.append([index])
            }
        }
        return rows
    }

    private func height(of rows: [[Int]], sizes: [CGSize]) -> CGFloat {
        rows.reduce(spacing * CGFloat(max(0, rows.count - 1))) { height, row in
            height + (row.map { sizes[$0].height }.max() ?? 0)
        }
    }
}

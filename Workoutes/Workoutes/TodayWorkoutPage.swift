import SwiftData
import SwiftUI
import UIKit

struct TodayWorkoutPage: View {
    let completions: [ExerciseCompletion]
    let week: DateInterval
    let isVisible: Bool
    @Binding var isCloudDragging: Bool

    @Query(sort: \TagGroup.name) private var groups: [TagGroup]
    @AppStorage(NextWorkoutNoteButton.storageKey) private var note = ""
    @AppStorage("appAccentColor") private var accentColorRawValue = ThemeColor.indigo.rawValue
    @Environment(ExerciseNavigation.self) private var navigation: ExerciseNavigation?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 44
    @State private var revealed = false
    @State private var showsGroups = false

    private var theme: ThemeColor { ThemeColor.resolve(accentColorRawValue) }
    private var isCloudInteractive: Bool { isVisible && scenePhase == .active && !showsGroups }

    var body: some View {
        let trained = Self.trainedGroupIDs(groups, completions: completions, week: week)
        let noteText = note.trimmingCharacters(in: .whitespacesAndNewlines)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "Workouts")
                    .font(.system(size: titleSize, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if !groups.isEmpty {
                    Text("This Week")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if groups.isEmpty {
                Text("No Groups")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cloud(trained: trained)
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

    static func trainedGroupIDs(_ groups: [TagGroup], completions: [ExerciseCompletion], week: DateInterval) -> Set<String> {
        let trainedTagIDs = Set(completions.lazy
            .filter { $0.completedAt >= week.start && $0.completedAt < week.end }
            .flatMap { $0.exercise?.tags ?? [] }
            .map(\.persistentModelID))
        return Set(groups.lazy.filter { !$0.tagIDs.isDisjoint(with: trainedTagIDs) }.map(\.stableID))
    }

    private func cloud(trained: Set<String>) -> some View {
        ViewThatFits(in: .vertical) {
            WorkoutGroupCloud(groups: groups, theme: theme, isInteractive: isCloudInteractive,
                              revealed: revealed, isDragging: $isCloudDragging) { group in
                pill(group, isTrained: trained.contains(group.stableID))
            }

            // Keep names readable on compact screens or with a large custom catalog.
            Button { showsGroups = true } label: {
                Text("Groups")
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
                    let isTrained = trained.contains(group.stableID)
                    groupButton(group, isTrained: isTrained) {
                        groupLabel(group, tint: groupColor(group, isTrained: isTrained))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                    }
                }
                .navigationTitle("Groups")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showsGroups = false }
                    }
                }
            }
        }
    }

    private func pill(_ group: TagGroup, isTrained: Bool) -> some View {
        let tint = groupColor(group, isTrained: isTrained)
        let intensity = colorScheme == .dark ? 0.48 : 0.36
        return groupButton(group, isTrained: isTrained) {
            groupLabel(group, tint: tint)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minHeight: 52)
                .contentShape(.capsule)
        }
            .glassEffect(.regular, in: .capsule)
            .background {
                if let tint {
                    EllipticalGradient(stops: [
                        .init(color: tint.opacity(intensity), location: 0),
                        .init(color: tint.opacity(intensity * 0.5), location: 0.42),
                        .init(color: tint.opacity(intensity * 0.1), location: 0.76),
                        .init(color: tint.opacity(0), location: 1)
                    ])
                    .frame(maxWidth: 180)
                    .padding(.horizontal, -12)
                    .padding(.vertical, -16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
    }

    private func groupButton<Label: View>(_ group: TagGroup, isTrained: Bool,
                                         @ViewBuilder label: () -> Label) -> some View {
        Button {
            showsGroups = false
            navigation?.showExercises(in: group)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: group.name))
        .accessibilityValue(isTrained ? Text("Trained This Week") : Text("Pending This Week"))
    }

    private func groupLabel(_ group: TagGroup, tint: Color?) -> some View {
        HStack(spacing: 8) {
            ExerciseGroupIcon(group: group, color: tint ?? .primary)
            Text(group.name)
            if tint != nil && differentiateWithoutColor {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private func groupColor(_ group: TagGroup, isTrained: Bool) -> Color? {
        isTrained ? Color(hex: group.resolvedColorHex(for: theme)) : nil
    }
}

private struct WorkoutGroupCloud<PillContent: View>: View {
    let groups: [TagGroup]
    let theme: ThemeColor
    let isInteractive: Bool
    let revealed: Bool
    @Binding var isDragging: Bool
    @ViewBuilder let capsule: (TagGroup) -> PillContent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulls: [WorkoutGroupCloudPull] = []
    @State private var capsuleFrames: [String: CGRect] = [:]
    @State private var cloudFrame = CGRect.zero

    var body: some View {
        let space = "workoutGroupCloud"
        let samples = pulls
        let returnDuration = 0.62
        WorkoutGroupCloudLayout {
            WorkoutGroupCloudTexture(theme: theme)
                .offset(WorkoutGroupCloudPull.cloudOffset(for: samples))
                .animation(reduceMotion ? nil : .smooth(duration: samples.isEmpty ? returnDuration : 0.32), value: samples)

            ForEach(Array(groups.enumerated()), id: \.element.stableID) { index, group in
                let id = group.stableID
                let ownPull = samples.first { $0.groupID == id }
                Group {
                    let content = capsule(group).compositingGroup()
                    if isInteractive && !reduceMotion {
                        content.modifier(WorkoutGroupDrift(index: index))
                    } else {
                        content
                    }
                }
                .opacity(revealed || reduceMotion ? 1 : 0)
                .offset(y: revealed || reduceMotion ? 0 : 8)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.28).delay(Double(min(index, 12)) * 0.035),
                           value: revealed)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { capsuleFrames[id] = $0 }
                .contentShape(.capsule)
                .visualEffect { content, geometry in
                    guard !samples.isEmpty else { return content.offset(.zero) }
                    let frame = geometry.frame(in: .named(space))
                    let bounds = geometry.bounds(of: .named(space))?.size
                    let offset = ownPull?.offset(for: id, frame: frame, in: bounds)
                        ?? WorkoutGroupCloudPull.neighborOffset(from: samples, for: id, frame: frame, in: bounds)
                    return content.offset(offset)
                }
                .animation(reduceMotion || ownPull != nil ? nil : .smooth(duration: samples.isEmpty ? returnDuration : 0.54),
                           value: samples)
                .zIndex(ownPull == nil ? 0 : 1)
            }
        }
        .coordinateSpace(name: space)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cloudFrame = $0 }
        .background {
            WorkoutGroupDrag(isEnabled: isInteractive && (revealed || reduceMotion),
                             targetAt: dragTarget, update: updatePulls)
        }
        .onChange(of: isInteractive) { _, isInteractive in
            if !isInteractive { updatePulls([]) }
        }
        .onDisappear { updatePulls([]) }
    }

    private func dragTarget(at point: CGPoint, excluding occupiedGroups: Set<String>) -> WorkoutGroupDragTarget? {
        let localPoint = CGPoint(x: point.x - cloudFrame.minX, y: point.y - cloudFrame.minY)
        return groups.lazy.compactMap { group -> WorkoutGroupDragTarget? in
            let id = group.stableID
            guard !occupiedGroups.contains(id), let frame = capsuleFrames[id] else { return nil }
            let offset = WorkoutGroupCloudPull.neighborOffset(from: pulls, for: id, frame: frame, in: cloudFrame.size)
            let presentedFrame = frame.offsetBy(dx: offset.width, dy: offset.height)
            // Include the few points used by the capsule's idle floating motion.
            let hitArea = Capsule().path(in: presentedFrame.insetBy(dx: -5, dy: -4))
            guard hitArea.contains(localPoint) else { return nil }
            return WorkoutGroupDragTarget(groupID: id, frame: frame, offset: offset)
        }.first
    }

    private func updatePulls(_ samples: [WorkoutGroupCloudPull]) {
        if pulls != samples { pulls = samples }
        let dragging = !samples.isEmpty
        if isDragging != dragging { isDragging = dragging }
    }
}

private struct WorkoutGroupDrag: UIViewRepresentable {
    let isEnabled: Bool
    let targetAt: (CGPoint, Set<String>) -> WorkoutGroupDragTarget?
    let update: ([WorkoutGroupCloudPull]) -> Void

    func makeUIView(context: Context) -> WorkoutGroupDragHost {
        WorkoutGroupDragHost()
    }

    func updateUIView(_ view: WorkoutGroupDragHost, context: Context) {
        view.update = isEnabled ? update : nil
        view.recognizer.targetAt = targetAt
        view.recognizer.isEnabled = isEnabled
    }

    static func dismantleUIView(_ view: WorkoutGroupDragHost, coordinator: ()) {
        view.recognizer.view?.removeGestureRecognizer(view.recognizer)
    }
}

private final class WorkoutGroupDragHost: UIView {
    let recognizer = WorkoutGroupDragRecognizer()
    var update: (([WorkoutGroupCloudPull]) -> Void)?

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        recognizer.isEnabled = false
        recognizer.addTarget(self, action: #selector(dragChanged))
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        recognizer.view?.removeGestureRecognizer(recognizer)
        // The window receives all contacts, including those on different SwiftUI buttons.
        window?.addGestureRecognizer(recognizer)
    }

    @objc private func dragChanged() {
        switch recognizer.state {
        case .began, .changed: update?(recognizer.pulls)
        case .ended, .cancelled: update?([])
        default: break
        }
    }
}

private struct WorkoutGroupDragTarget {
    let groupID: String
    let frame: CGRect
    let offset: CGSize
}

/// Batch every touch in a UIKit event before publishing positions to SwiftUI.
private final class WorkoutGroupDragRecognizer: UIGestureRecognizer {
    private struct Contact {
        let touch: UITouch
        let target: WorkoutGroupDragTarget
        let start: CGPoint
        var pull: WorkoutGroupCloudPull?
    }

    var targetAt: ((CGPoint, Set<String>) -> WorkoutGroupDragTarget?)?
    private var contacts: [Contact] = []
    var pulls: [WorkoutGroupCloudPull] { contacts.compactMap(\.pull) }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // A touch on the background fails immediately, so horizontal paging can still start there.
        guard let scrollView = otherGestureRecognizer.view as? UIScrollView else { return false }
        return scrollView.panGestureRecognizer == otherGestureRecognizer
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        var occupiedGroups = Set(contacts.map(\.target.groupID))
        for touch in touches {
            let start = touch.location(in: touch.window)
            guard let target = targetAt?(start, occupiedGroups) else {
                ignore(touch, for: event)
                continue
            }
            occupiedGroups.insert(target.groupID)
            contacts.append(Contact(touch: touch, target: target, start: start))
        }
        if contacts.isEmpty { state = .failed }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        var changed = false
        for index in contacts.indices where touches.contains(contacts[index].touch) {
            let contact = contacts[index]
            let point = contact.touch.location(in: contact.touch.window)
            let dx = point.x - contact.start.x
            let dy = point.y - contact.start.y
            guard contact.pull != nil || hypot(dx, dy) >= 6 else { continue }
            let target = contact.target
            contacts[index].pull = WorkoutGroupCloudPull(
                groupID: target.groupID, sourceFrame: target.frame,
                translation: CGSize(width: target.offset.width + dx, height: target.offset.height + dy)
            )
            changed = true
        }
        if changed { state = state == .possible ? .began : .changed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        remove(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        remove(touches, cancelled: true)
    }

    override func reset() {
        super.reset()
        contacts.removeAll()
    }

    private func remove(_ touches: Set<UITouch>, cancelled: Bool) {
        contacts.removeAll { touches.contains($0.touch) }
        switch state {
        case .possible:
            if contacts.isEmpty { state = .failed }
        case .began, .changed:
            state = contacts.isEmpty ? (cancelled ? .cancelled : .ended) : .changed
        default: break
        }
    }
}

private nonisolated struct WorkoutGroupCloudPull: Equatable, Sendable {
    let groupID: String
    let sourceFrame: CGRect
    let translation: CGSize

    var cloudOffset: CGSize {
        CGSize(width: 36 * tanh(translation.width / 108), height: 30 * tanh(translation.height / 96))
    }

    static func cloudOffset(for pulls: [Self]) -> CGSize {
        guard !pulls.isEmpty else { return .zero }
        let sum = pulls.reduce(into: CGSize.zero) { offset, pull in
            let shift = pull.cloudOffset
            offset.width += shift.width
            offset.height += shift.height
        }
        return CGSize(width: sum.width / CGFloat(pulls.count), height: sum.height / CGFloat(pulls.count))
    }

    static func neighborOffset(from pulls: [Self], for id: String, frame: CGRect, in bounds: CGSize?) -> CGSize {
        guard !pulls.isEmpty else { return .zero }
        if pulls.count == 1 { return pulls[0].offset(for: id, frame: frame, in: bounds) }
        let sum = pulls.reduce(into: CGSize.zero) { offset, pull in
            let influence = pull.offset(for: id, frame: frame, in: bounds)
            offset.width += influence.width
            offset.height += influence.height
        }
        let falloff = sqrt(CGFloat(pulls.count))
        return confined(CGSize(width: sum.width / falloff, height: sum.height / falloff), for: frame, in: bounds)
    }

    func offset(for id: String, frame: CGRect, in bounds: CGSize?) -> CGSize {
        let dragged = Self.confined(translation, for: sourceFrame, in: bounds)
        guard id != groupID else { return dragged }

        // Measure proximity in units of the two capsule sizes, including the space around them.
        let reachX = (frame.width + sourceFrame.width) / 2 + 22
        let reachY = (frame.height + sourceFrame.height) / 2 + 22
        let dx = (frame.midX - sourceFrame.midX) / reachX
        let dy = (frame.midY - sourceFrame.midY) / reachY
        var x = dx - dragged.width / reachX
        var y = dy - dragged.height / reachY
        let distance = hypot(x, y)
        let dragAmount = 1 - exp(-hypot(dragged.width, dragged.height) / 44)
        let squaredDistance = distance * distance
        // A wide falloff moves the surrounding capsules, with more room opening near contact.
        let strength = dragAmount * (22 * exp(-0.45 * squaredDistance) + 36 * exp(-2.5 * squaredDistance))

        // When their centers nearly coincide, favor sliding sideways into the available space.
        let sideways = max(0, 0.29 - distance)
        if abs(dx) > abs(dy) {
            y += frame.midY > (bounds?.height ?? 0) / 2 ? -sideways : sideways
        } else {
            x += frame.midX > (bounds?.width ?? 0) / 2 ? -sideways : sideways
        }
        let push = strength / max(0.19, hypot(x, y))
        let nearbyOffset = CGSize(width: x * push, height: y * push)
        return Self.confined(nearbyOffset, for: frame, in: bounds)
    }

    private static func confined(_ offset: CGSize, for frame: CGRect, in bounds: CGSize?) -> CGSize {
        guard let bounds else { return offset }
        return CGSize(width: min(max(offset.width, min(0, -frame.minX)), max(0, bounds.width - frame.maxX)),
                      height: min(max(offset.height, min(0, -frame.minY)), max(0, bounds.height - frame.maxY)))
    }
}

private struct WorkoutGroupDrift: ViewModifier {
    let index: Int
    @State private var isDrifting = false

    func body(content: Content) -> some View {
        // Keep each excursion smaller than the gap between neighboring capsules.
        let horizontal: CGFloat = index.isMultiple(of: 2) ? 4.5 : -4.5
        let vertical: CGFloat = index % 4 < 2 ? -3.5 : 3.5
        return content
            .offset(x: isDrifting ? horizontal : 0)
            .animation(.easeInOut(duration: 4.6 + Double(index % 5) * 0.47).repeatForever(), value: isDrifting)
            .offset(y: isDrifting ? vertical : 0)
            .animation(.easeInOut(duration: 3.8 + Double((index + 2) % 4) * 0.63).repeatForever(), value: isDrifting)
            .task {
                // Start after the capsule has rendered and its entrance has begun.
                try? await Task.sleep(for: .milliseconds(760))
                guard !Task.isCancelled else { return }
                isDrifting = true
            }
    }
}

private struct WorkoutGroupCloudTexture: View {
    let theme: ThemeColor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tint = Color(hex: theme.hex(for: colorScheme))
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

private struct WorkoutGroupCloudLayout: Layout {
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

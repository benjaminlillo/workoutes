import SwiftData
import SwiftUI

struct TagWheelPicker: View {
    let tags: [Tag]
    @Binding var selection: PersistentIdentifier?
    var onAdd: () -> Void
    var onEdit: (Tag) -> Void
    var onDelete: (Tag) -> Void
    var screenCenter = CGPoint(x: 142, y: 142)
    var selectionAngle = TagWheelPosition.selectionAngle
    var onMove: (CGSize) -> Void = { _ in }
    var onMoveEnded: (CGSize) -> Void = { _ in }
    var onMoveCancelled: () -> Void = {}
    var onDock: (TagWheelDock.Edge) -> Void = { _ in }

    static let diameter: CGFloat = 284
    static let scale: CGFloat = 0.82
    // Keeps the original vertical placement until the user chooses a dock position.
    static let bottomInset: CGFloat = 130

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var wheel = TagWheelPosition()
    @State private var drag = TagWheelDrag()
    @State private var interactionCenter: CGPoint?
    @State private var isMoving = false
    @GestureState private var gestureIsActive = false

    private var count: Int { tags.count }
    private var selectedIndex: Int? {
        selection.flatMap { id in tags.firstIndex { $0.persistentModelID == id } }
    }
    private var selectedTag: Tag? { selectedIndex.map { tags[$0] } }
    private var isInactive: Bool { selectedIndex == nil }
    private var snapAnimation: Animation? { reduceMotion ? nil : .snappy(duration: 0.3, extraBounce: 0.04) }
    private var colorAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.35) }

    var body: some View {
        observedDisc
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Filter by Tag")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Rotate to select a tag. Drag the center to move the wheel. Manage tags in the toolbar.")
        .accessibilityAdjustableAction { adjustSelection($0) }
        .accessibilityActions {
            Button("Deselect All Tags") { deactivate() }
            Button("Add Tag") { onAdd() }
            Button("Move Wheel to Left Edge") { onDock(.leading) }
            Button("Move Wheel to Right Edge") { onDock(.trailing) }
            Button("Move Wheel to Top Edge") { onDock(.top) }
            Button("Move Wheel to Bottom Edge") { onDock(.bottom) }
            if let selectedTag {
                Button("Edit Tag") { onEdit(selectedTag) }
                Button("Delete Tag") { onDelete(selectedTag) }
            }
        }
        .accessibilityIdentifier("tag-wheel")
    }

    private var positionedDisc: some View {
        disc
        .contentShape(Circle())
        .highPriorityGesture(wheelGesture)
        .scaleEffect(Self.scale)
    }

    private var observedDisc: some View {
        positionedDisc
        .sensoryFeedback(.selection, trigger: selection)
        .onChange(of: selection, initial: true) { synchronizeSelection() }
        .onChange(of: tags.map(\.persistentModelID)) { synchronizeSelection(force: true) }
        .onDisappear(perform: resetInteraction)
        .onChange(of: gestureIsActive) { _, active in
            if !active {
                if isMoving { onMoveCancelled() }
                resetInteraction()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { resetInteraction() }
        }
    }

    private var disc: some View {
        ZStack {
            plate
                .accessibilityHidden(true)
            Circle().fill(.clear)
                .contentShape(Circle())
                .gesture(SpatialTapGesture().onEnded { chooseTag(at: $0.location) })

            ForEach(tags) { tag in
                let index = tags.firstIndex { $0.persistentModelID == tag.persistentModelID } ?? 0
                let angle = selectionAngle
                    - (Double(index) - wheel.position) * TagWheelPosition.angularSpacing(for: count)
                TagWheelSlot(tag: tag, angle: angle, count: count, isSelected: index == selectedIndex,
                             onChoose: { toggleTag(index) }, onEdit: { onEdit(tag) }, onDelete: { onDelete(tag) })
                    .animation(colorAnimation) { content in
                        content.opacity(isInactive ? 0.65 : 1)
                    }
            }

            TagWheelGrip()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
        }
        .frame(width: Self.diameter, height: Self.diameter)
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        let index = selectedIndex ?? wheel.selectedIndex(count: count)
        switch direction {
        case .increment: choose(TagWheelPosition.wrappedIndex(index + 1, count: count))
        case .decrement: choose(TagWheelPosition.wrappedIndex(index - 1, count: count))
        @unknown default: break
        }
    }

    private var accessibilityValue: String {
        guard let selectedTag, let selectedIndex else { return "No Tag Selected" }
        return "\(selectedTag.name), \(selectedIndex + 1) of \(count)"
    }

    private var plate: some View {
        ZStack {
            Color.clear
                .glassEffect(.regular.tint(.white.opacity(colorScheme == .dark ? 0.22 : 0.55)),
                             in: ContinuousPlateShape())
            Color.clear
                .frame(width: 78, height: 78)
                .glassEffect(.regular, in: PlateHubShape())
        }
        .allowsHitTesting(false)
    }

    private var wheelGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(DockableTagWheel.coordinateSpace))
            .updating($gestureIsActive) { _, active, _ in active = true }
            .onChanged { value in
                let center = interactionCenter ?? screenCenter
                if interactionCenter == nil {
                    interactionCenter = center
                    isMoving = hypot(value.startLocation.x - center.x, value.startLocation.y - center.y) < 42 * Self.scale
                }
                if isMoving {
                    onMove(value.translation)
                    return
                }
                let previousIntent = drag.intent
                let start = CGPoint(x: (value.startLocation.x - center.x) / Self.scale,
                                    y: (value.startLocation.y - center.y) / Self.scale)
                let location = CGPoint(x: (value.location.x - center.x) / Self.scale,
                                       y: (value.location.y - center.y) / Self.scale)
                drag.update(start: start, location: location, center: .zero)
                guard drag.intent == .rotation else { return }
                if previousIntent != .rotation {
                    wheel.drag(to: angle(at: value.startLocation, around: center), count: count)
                }
                wheel.drag(to: angle(at: value.location, around: center), count: count)
                // A first turn activates the filter on release; an active filter follows the rotation.
                if !isInactive { updateSelection() }
            }
            .onEnded { value in
                if isMoving {
                    onMoveEnded(value.translation)
                    resetInteraction()
                    return
                }
                interactionCenter = nil
                switch drag.intent {
                case .rotation:
                    drag = TagWheelDrag()
                    withAnimation(snapAnimation) { wheel.snap() }
                    updateSelection()
                case .radial, .undecided:
                    drag = TagWheelDrag()
                }
            }
    }

    private func angle(at point: CGPoint, around center: CGPoint) -> Double {
        atan2(point.y - center.y, point.x - center.x)
    }

    private func chooseTag(at point: CGPoint) {
        let center = CGPoint(x: Self.diameter / 2, y: Self.diameter / 2)
        guard hypot(point.x - center.x, point.y - center.y) >= 42 else { return }
        guard !tags.isEmpty else { onAdd(); return }
        let index = wheel.index(at: angle(at: point, around: center), count: count, referenceAngle: selectionAngle)
        toggleTag(index)
    }

    private func toggleTag(_ index: Int) {
        if selectedIndex == index { deactivate() }
        else { choose(index) }
    }

    private func choose(_ index: Int) {
        guard tags.indices.contains(index) else { return }
        drag = TagWheelDrag()
        selection = tags[index].persistentModelID
        withAnimation(snapAnimation) { wheel.select(index, count: count) }
    }

    private func deactivate() {
        withAnimation(snapAnimation) {
            drag = TagWheelDrag()
            wheel.snap()
            selection = nil
        }
    }

    private func resetInteraction() {
        interactionCenter = nil
        isMoving = false
        drag = TagWheelDrag()
        wheel.snap()
    }

    private func updateSelection() {
        guard !tags.isEmpty else { return }
        let id = tags[wheel.selectedIndex(count: count)].persistentModelID
        if selection != id { selection = id }
    }

    private func synchronizeSelection(force: Bool = false) {
        guard let selectedIndex else {
            drag = TagWheelDrag()
            withAnimation(snapAnimation) { wheel.select(wheel.selectedIndex(count: count), count: max(1, count)) }
            return
        }
        guard force || wheel.selectedIndex(count: count) != selectedIndex else { return }
        drag = TagWheelDrag()
        withAnimation(snapAnimation) { wheel.select(selectedIndex, count: count) }
    }
}

/// Interpolating the angle keeps icons and inscriptions on a circular path while snapping.
private struct TagWheelSlot: View, Animatable {
    let tag: Tag
    var angle: Double
    let count: Int
    let isSelected: Bool
    let onChoose: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    private let iconRadius = 84.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private var color: Color {
        isSelected ? Color(hex: tag.colorHex) : Color(white: colorScheme == .dark ? 0.72 : 0.43)
    }
    private var iconSize: CGFloat {
        let base: CGFloat
        switch tag.muscleIcon {
        case nil: base = 20
        case .fullBody, .lowerBody, .forearms, .quadriceps, .hamstrings, .adductors: base = 48
        default: base = 40
        }
        let available = 2 * sin(TagWheelPosition.angularSpacing(for: count) / 2) * iconRadius - 8
        let scale = count <= 2 ? 1 : min(1, max(0.42, available / 48))
        return base * scale
    }

    var body: some View {
        ZStack {
            ZStack {
                // Keep the artwork outside the context menu's lifted source view.
                // Its preview can otherwise pin the icon while the disc rotates underneath it.
                Group {
                    if let icon = tag.muscleIcon {
                        MuscleIconView(icon: icon, color: color)
                            .frame(width: iconSize, height: iconSize)
                    } else {
                        Circle().fill(color).frame(width: iconSize, height: iconSize)
                    }
                }
                .frame(width: 50, height: 50)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: color)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                Button(action: onChoose) {
                    Color.clear.frame(width: 50, height: 50)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tag.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier(isSelected ? "tag-wheel-selected" : "tag-wheel-option")
                .contextMenu {
                    Button("Edit Tag", systemImage: "pencil", action: onEdit)
                    Button("Delete Tag", systemImage: "trash", role: .destructive, action: onDelete)
                }
            }
            .position(x: TagWheelPicker.diameter / 2 + cos(angle) * iconRadius,
                      y: TagWheelPicker.diameter / 2 + sin(angle) * iconRadius)
            PlateInscription(text: tag.name, angle: angle,
                             arc: min(80 * .pi / 180, TagWheelPosition.angularSpacing(for: count) * 0.82), color: color)
        }
        .frame(width: TagWheelPicker.diameter, height: TagWheelPicker.diameter)
    }
}

/// A continuous rim with only the Olympic bar's central bore cut out of the glass.
private struct ContinuousPlateShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect)
            .subtracting(Path(ellipseIn: CGRect(x: rect.midX - 29, y: rect.midY - 29, width: 58, height: 58)))
    }
}

private struct PlateHubShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect).subtracting(Path(ellipseIn: rect.insetBy(dx: 7, dy: 7)))
    }
}

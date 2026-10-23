import SwiftData
import SwiftUI

struct TagWheelPicker: View {
    let tags: [Tag]
    @Binding var selection: PersistentIdentifier?
    var onAdd: () -> Void
    var onEdit: (Tag) -> Void
    var onDelete: (Tag) -> Void

    static let diameter: CGFloat = 284
    static let overhang: CGFloat = 78
    // Fixed distance from the display's bottom edge; leaves room for the expanded bottom bars.
    static let bottomInset: CGFloat = 130

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var wheel = TagWheelPosition()
    @State private var drag = TagWheelDrag()

    private var count: Int { tags.count }
    private var selectedIndex: Int? {
        selection.flatMap { id in tags.firstIndex { $0.persistentModelID == id } }
    }
    private var selectedTag: Tag? { selectedIndex.map { tags[$0] } }
    private var isInactive: Bool { selectedIndex == nil }
    private var selectedColor: Color { selectedTag.map { Color(hex: $0.colorHex) } ?? .secondary }
    private var snapAnimation: Animation? { reduceMotion ? nil : .snappy(duration: 0.3, extraBounce: 0.04) }
    private var colorAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.35) }

    var body: some View {
        observedDisc
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Filter by Tag")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Rotate to select a tag. Tap the selected tag to deselect it. More actions let you manage tags.")
        .accessibilityAdjustableAction { adjustSelection($0) }
        .accessibilityActions {
            Button("Deselect All Tags") { deactivate() }
            Button("Add Tag") { onAdd() }
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
        .scaleEffect(0.82)
        .offset(x: 46)
    }

    private var observedDisc: some View {
        positionedDisc
        .sensoryFeedback(.selection, trigger: selection)
        .onChange(of: selection, initial: true) { synchronizeSelection() }
        .onChange(of: tags.map(\.persistentModelID)) { synchronizeSelection(force: true) }
        .onDisappear(perform: resetInteraction)
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
                let angle = TagWheelPosition.selectionAngle
                    - (Double(index) - wheel.position) * TagWheelPosition.angularSpacing(for: count)
                TagWheelSlot(tag: tag, angle: angle, count: count, isSelected: index == selectedIndex,
                             onChoose: { toggleTag(index) }, onEdit: { onEdit(tag) }, onDelete: { onDelete(tag) })
                    .animation(colorAnimation) { content in
                        content.opacity(isInactive ? 0.65 : 1)
                    }
            }

            centerMenu
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

    private var centerMenu: some View {
        TagWheelMenu(tags: tags, selection: selection, color: selectedColor,
                     onChoose: { tag in
                         if let index = tags.firstIndex(where: { $0.persistentModelID == tag.persistentModelID }) {
                             toggleTag(index)
                         }
                     }, onDeselect: deactivate, onAdd: onAdd, onEdit: onEdit, onDelete: onDelete)
            .frame(width: 48, height: 48)
    }

    private var wheelGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let center = CGPoint(x: Self.diameter / 2, y: Self.diameter / 2)
                let previousIntent = drag.intent
                drag.update(start: value.startLocation, location: value.location, center: center)
                guard drag.intent == .rotation else { return }
                if previousIntent != .rotation {
                    wheel.drag(to: angle(at: value.startLocation, around: center), count: count)
                }
                wheel.drag(to: angle(at: value.location, around: center), count: count)
                // A first turn activates the filter on release; an active filter follows the rotation.
                if !isInactive { updateSelection() }
            }
            .onEnded { _ in
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
        guard !tags.isEmpty else { onAdd(); return }
        let center = CGPoint(x: Self.diameter / 2, y: Self.diameter / 2)
        let index = hypot(point.x - center.x, point.y - center.y) < 42
            ? wheel.selectedIndex(count: count) : wheel.index(at: angle(at: point, around: center), count: count)
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

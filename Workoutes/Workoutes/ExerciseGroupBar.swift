import SwiftData
import SwiftUI

struct ExerciseGroupBar: View {
    let groups: [TagGroup]
    @Binding var selection: PersistentIdentifier?
    @Binding var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motion: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.42)
    }

    private var selectedGroup: TagGroup? {
        groups.first { $0.persistentModelID == selection }
    }

    var body: some View {
        GeometryReader { geometry in
            let group = selectedGroup
            let availableWidth = min(geometry.size.width, 440)
            let namedWidth = min(180, availableWidth * 0.45)
            let showsName = group != nil && !isExpanded
            let triggerWidth = showsName ? namedWidth : 52
            let optionsWidth = max(52, availableWidth - 64)
            let expansionMotion = motion?.delay(isExpanded && group != nil ? 0.09 : 0)
            // The glass resizes inside a stable full-width coordinate space. The
            // scroll view keeps its expanded width while the two surfaces resize.
            Color.clear
                .overlay(alignment: .trailing) {
                    ZStack(alignment: .trailing) {
                        Color.clear
                            .frame(width: isExpanded ? optionsWidth : 52, height: 52)
                            .glassEffect(.regular, in: .capsule)
                            .opacity(isExpanded ? 1 : 0)

                        expandedBar
                            .frame(width: optionsWidth, height: 52)
                            .opacity(isExpanded ? 1 : 0)
                            .mask(alignment: .trailing) {
                                Capsule().frame(width: isExpanded ? optionsWidth : 52, height: 52)
                            }
                    }
                    .padding(.trailing, triggerWidth + 12)
                    .allowsHitTesting(isExpanded)
                    .accessibilityHidden(!isExpanded)
                }

                .overlay(alignment: .trailing) {
                    Button {
                        setExpanded(!isExpanded)
                    } label: {
                        groupIcon(group)
                            .frame(width: 34, height: 34)
                            .padding(.leading, showsName ? 12 : 9)
                            .frame(width: triggerWidth, height: 52, alignment: .leading)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .accessibilityLabel(isExpanded ? Text("Close") : Text("Filter by Group"))
                    .accessibilityValue(group?.name ?? String(localized: "All Exercises"))
                    .accessibilityIdentifier(isExpanded ? "close-group-filter" : "exercise-group-filter")
                }
                .overlay(alignment: .trailing) {
                    // Use the closed button's bounds throughout the fade so the name stays still.
                    let nameLeading: CGFloat = 54
                    Text(group?.name ?? "")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .frame(width: max(0, namedWidth - nameLeading - 12), alignment: .leading)
                        .padding(.leading, nameLeading)
                        .frame(width: namedWidth, height: 52, alignment: .leading)
                        .opacity(showsName ? 1 : 0)
                        .animation(nameAnimation(showing: showsName), value: showsName)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .animation(motion, value: selection)
                .animation(expansionMotion, value: isExpanded)
        }
        .frame(height: 52)
        .sensoryFeedback(.selection, trigger: selection)
        .onDisappear { isExpanded = false }
    }

    private func nameAnimation(showing: Bool) -> Animation? {
        guard !reduceMotion else { return nil }
        // Fade out before the capsule crops the name, and fade back in once it has room.
        return showing ? .easeOut(duration: 0.17).delay(0.29) : .easeOut(duration: 0.08)
    }

    private var expandedBar: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        filterButton(nil)
                            .id("all-groups")
                        ForEach(groups) { group in
                            filterButton(group)
                                .id(group.persistentModelID)
                        }
                    }
                    .padding(4)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .onChange(of: isExpanded, initial: true) { _, expanded in
                    guard expanded else { return }
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if let selection { proxy.scrollTo(selection, anchor: .center) }
                        else { proxy.scrollTo("all-groups", anchor: .leading) }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by Group")
        .accessibilityIdentifier("exercise-group-bar")
        .accessibilityAction(.escape) { setExpanded(false) }
    }

    private func filterButton(_ group: TagGroup?) -> some View {
        let isSelected = selection == group?.persistentModelID
        return Button {
            selection = group?.persistentModelID
            setExpanded(false)
        } label: {
            HStack(spacing: 8) {
                groupIcon(group)
                    .frame(width: 34, height: 34)
                Text(group?.name ?? String(localized: "All Exercises"))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background {
                    if isSelected {
                        Capsule().fill(.primary.opacity(0.10))
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group?.name ?? String(localized: "All Exercises"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func groupIcon(_ group: TagGroup?) -> some View {
        if let group {
            ExerciseGroupIcon(group: group)
        } else {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: ExerciseToolbarStyle.symbolSize, weight: .medium))
        }
    }

    private func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
    }
}

struct ExerciseGroupIcon: View {
    let group: TagGroup
    var color: Color = .primary

    var body: some View {
        let icons = group.compositionIcons
        Group {
            if icons.isEmpty {
                Image(systemName: "tag")
                    .font(.system(size: ExerciseToolbarStyle.symbolSize, weight: .medium))
                    .foregroundStyle(color)
            } else {
                TintedMuscleComposition(icons: icons, color: color)
            }
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }
}

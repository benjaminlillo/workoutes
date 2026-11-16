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
            let availableWidth = min(geometry.size.width, 440)
            let triggerWidth = selectedGroup == nil ? 52 : min(180, availableWidth * 0.45)
            let optionsWidth = max(52, availableWidth - triggerWidth - 12)
            // The glass resizes inside a stable full-width coordinate space. The
            // trigger must not inherit the changing proposal or it jumps during layout.
            ZStack(alignment: .trailing) {
                Color.clear
                    .frame(width: isExpanded ? optionsWidth : 52, height: 52)
                    .glassEffect(.regular, in: .capsule)
                    .opacity(isExpanded ? 1 : 0)
                    .padding(.trailing, triggerWidth + 12)
                    .animation(motion, value: isExpanded)

                expandedBar
                    .frame(width: optionsWidth, height: 52)
                    .opacity(isExpanded ? 1 : 0)
                    .mask(alignment: .trailing) {
                        Capsule().frame(width: isExpanded ? optionsWidth : 52, height: 52)
                    }
                    .padding(.trailing, triggerWidth + 12)
                    .animation(motion, value: isExpanded)
                    .allowsHitTesting(isExpanded)
                    .accessibilityHidden(!isExpanded)

                Button {
                    setExpanded(!isExpanded)
                } label: {
                    HStack(spacing: 8) {
                        groupIcon(selectedGroup)
                            .frame(width: 34, height: 34)
                        if let selectedGroup {
                            Text(selectedGroup.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, selectedGroup == nil ? 9 : 12)
                    .frame(width: triggerWidth, height: 52)
                    .clipShape(.capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityLabel(isExpanded ? Text("Close") : Text("Filter by Group"))
                .accessibilityValue(selectedGroup?.name ?? String(localized: "All Exercises"))
                .accessibilityIdentifier(isExpanded ? "close-group-filter" : "exercise-group-filter")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .animation(motion, value: selection)
        }
        .frame(height: 52)
        .sensoryFeedback(.selection, trigger: selection)
        .onDisappear { isExpanded = false }
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
            if group.compositionIcons.isEmpty {
                Image(systemName: "tag")
                    .font(.system(size: ExerciseToolbarStyle.symbolSize, weight: .medium))
            } else {
                TintedMuscleComposition(icons: group.compositionIcons, color: .primary)
                    .frame(width: 34, height: 34)
            }
        } else {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: ExerciseToolbarStyle.symbolSize, weight: .medium))
        }
    }

    private func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
    }
}

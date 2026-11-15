import SwiftData
import SwiftUI

struct ExerciseGroupBar: View {
    let groups: [TagGroup]
    @Binding var selection: PersistentIdentifier?

    @AppStorage("appAccentColor") private var accentColor = ThemeColor.indigo.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let width = max(44, (geometry.size.width - 8) / CGFloat(max(groups.count, 1)))
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(groups) { group in
                            groupButton(group, width: width)
                                .id(group.persistentModelID)
                        }
                    }
                    .padding(4)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .onChange(of: selection, initial: true) { _, selected in
                    guard let selected else { return }
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                        proxy.scrollTo(selected)
                    }
                }
            }
        }
        .frame(height: 52)
        .clipShape(.capsule)
        .glassEffect(.regular, in: .capsule)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by Group")
        .accessibilityIdentifier("exercise-group-bar")
    }

    private func groupButton(_ group: TagGroup, width: CGFloat) -> some View {
        let id = group.persistentModelID
        let isSelected = selection == id
        let color = Color(hex: group.resolvedColorHex(for: ThemeColor.resolve(accentColor)))
        let ink = isSelected ? color : Color(white: colorScheme == .dark ? 0.74 : 0.36)
        let icons = group.compositionIcons

        return Button {
            selection = isSelected ? nil : id
        } label: {
            Group {
                if icons.isEmpty {
                    Circle().fill(ink).frame(width: 13, height: 13)
                } else {
                    TintedMuscleComposition(icons: icons, color: ink)
                        .frame(width: 34, height: 34)
                }
            }
            .frame(width: width, height: 44)
            .background {
                if isSelected {
                    Capsule()
                        .fill(color.opacity(0.20))
                        .matchedGeometryEffect(id: "selection", in: highlight)
                }
            }
            .contentShape(.rect)
            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: selection)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? Text("Clear Group Filter") : Text("Filter by Group"))
    }
}

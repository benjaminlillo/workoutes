import SwiftUI

/// The exercise card and Live Activity use the same header and tag geometry.
struct ExerciseCardHeader<StatusControl: View>: View {
    let title: String
    let subtitle: String
    let details: String
    let increaseLoadNextTime: Bool
    let accentColor: Color
    let tagColors: [String]
    var tagIconNames: [String?] = []
    var tagNames: [String] = []
    var tagIconHeight: CGFloat = 44
    @ViewBuilder var statusControl: () -> StatusControl

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.bold))

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !details.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Image(systemName: "doc.text")
                        Text(details)
                            .lineLimit(2)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: 4) {
                if increaseLoadNextTime {
                    ExerciseBumpBadge(color: accentColor)
                        .frame(minHeight: 44)
                }

                VStack(spacing: 5) {
                    statusControl()
                    if !tagColors.isEmpty {
                        tagIcons
                    }
                }
            }
            .frame(minWidth: 44)
        }
    }

    private var tagIcons: some View {
        let tags = tagColors.enumerated().map { index, color in
            let icon = tagIconNames.indices.contains(index)
                ? tagIconNames[index].flatMap(MuscleIcon.init(rawValue:)) : nil
            let name = tagNames.indices.contains(index) ? tagNames[index] : icon?.name ?? String(localized: "Tag")
            return (icon: icon, color: color, name: name)
        }
        let composition = MuscleComposition(
            highlights: tags.compactMap { tag in tag.icon.map { .init(icon: $0, colorHex: tag.color) } },
            dotColors: tags.filter { $0.icon == nil }.map(\.color)
        )
        return ComposedMuscleIcon(composition: composition,
                                  size: CGSize(width: 44, height: composition.highlights.isEmpty ? 12 : tagIconHeight))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tags.map(\.name).joined(separator: ", "))
    }
}

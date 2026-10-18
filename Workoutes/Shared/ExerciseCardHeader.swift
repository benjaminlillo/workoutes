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
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 3),
                                 count: min(3, tagColors.count)), alignment: .trailing, spacing: 3) {
            ForEach(tagColors.indices, id: \.self) { index in
                let icon = tagIconNames.indices.contains(index)
                    ? tagIconNames[index].flatMap(MuscleIcon.init(rawValue:)) : nil
                Group {
                    if let icon {
                        MuscleIconView(icon: icon, color: Color(hex: tagColors[index]))
                            .frame(width: 20, height: 20)
                    } else {
                        Circle()
                            .fill(Color(hex: tagColors[index]))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityLabel(tagNames.indices.contains(index) ? "Tag: \(tagNames[index])" : icon?.name ?? "Tag")
            }
        }
        .fixedSize()
    }
}

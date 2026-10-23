import SwiftUI

struct TagLabel: View {
    let tag: Tag
    var isSelected = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon = tag.muscleIcon {
                MuscleIconView(icon: icon, color: Color(hex: tag.colorHex))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            } else {
                Circle().fill(Color(hex: tag.colorHex)).frame(width: 8, height: 8)
            }
            Text(tag.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hex: tag.colorHex))
            }
        }
    }
}

struct TagSelectionLabel: View {
    let tag: Tag
    let isSelected: Bool

    var body: some View {
        TagLabel(tag: tag, isSelected: isSelected)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background {
                Capsule()
                    .fill(isSelected ? Color(hex: tag.colorHex).opacity(0.18) : Color.secondary.opacity(0.1))
                    .subtleCardShadow()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tag.name)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

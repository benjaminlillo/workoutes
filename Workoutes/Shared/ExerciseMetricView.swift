import SwiftUI

struct ExerciseMetricView: View {
    let systemImage: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(label.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

struct ExerciseBumpBadge: View {
    let color: Color

    var body: some View {
        Image(systemName: "arrow.up.right.circle")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 26, height: 26)
            .background(color.opacity(0.14), in: Circle())
            .accessibilityLabel("Bump enabled")
    }
}

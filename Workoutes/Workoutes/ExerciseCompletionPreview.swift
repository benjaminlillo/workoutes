import SwiftUI

struct ExerciseCompletionPreview: View {
    let completedAt: Date
    let snapshot: ExerciseCompletionSnapshot?

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
        }
        .frame(idealWidth: 340, maxWidth: 360, maxHeight: 520)
        .padding(12)
        .accessibilityIdentifier("exerciseCompletionPreview")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(completedAt, format: .dateTime.year().month(.abbreviated).day().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if let snapshot {
                ExerciseCompletionCard(snapshot: snapshot)
            } else {
                ContentUnavailableView("No Historical Snapshot", systemImage: "clock.arrow.circlepath",
                                       description: Text("Exercise details weren't saved for this entry."))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Shares the card's presentation without exposing any edit or exercise-session controls.
struct ExerciseCompletionCard: View {
    let snapshot: ExerciseCompletionSnapshot
    @AppStorage("appAccentColor") private var accentColorRawValue = ThemeColor.indigo.rawValue
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .metric
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accentColor: Color { ThemeColor.resolve(accentColorRawValue).color }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ExerciseCardHeader(
                title: snapshot.title, subtitle: snapshot.subtitle, details: snapshot.details,
                increaseLoadNextTime: snapshot.increaseLoadNextTime, accentColor: accentColor,
                tagColors: snapshot.tags.map(\.colorHex), tagIconNames: snapshot.tags.map(\.iconName),
                tagNames: snapshot.tags.map(\.name)
            ) {
                ExerciseStatusSymbol(status: .done, accentColor: accentColor)
                    .accessibilityLabel("Exercise completed")
            }

            Divider()

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 0))
            layout {
                metric("Weight", systemImage: "dumbbell.fill", value: weightUnit.label(for: snapshot.weight))
                metricDivider
                metric("Sets", systemImage: "square.stack.3d.up.fill", value: "\(snapshot.numberOfSets) sets")
                metricDivider
                metric("Repetitions", systemImage: "repeat", value: "\(snapshot.reps) reps")
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .subtleCardBorder()
    }

    @ViewBuilder
    private func metric(_ label: String, systemImage: String, value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: 12) {
                Image(systemName: systemImage).font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 4) {
                    Text(value).font(.subheadline.bold())
                    Text(label.uppercased()).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            ExerciseMetricView(systemImage: systemImage, value: value, label: label)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    @ViewBuilder
    private var metricDivider: some View {
        if dynamicTypeSize.isAccessibilitySize { Divider() }
        else { Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 1, height: 42) }
    }
}

struct WeeklyExerciseBlock: View {
    let completion: ExerciseCompletion
    let height: CGFloat
    @State var isPreviewPresented = false

    var body: some View {
        Button { isPreviewPresented = true } label: {
            HStack(spacing: 0) {
                let colors = completion.tagColors
                if colors.isEmpty {
                    Color.gray.opacity(0.5)
                } else {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, hex in Color(hex: hex) }
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .highPriorityGesture(LongPressGesture(minimumDuration: 0.25).onEnded { _ in isPreviewPresented = true })
        .popover(isPresented: $isPreviewPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            ExerciseCompletionPreview(completedAt: completion.completedAt, snapshot: completion.snapshot)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel(completion.snapshot?.title ?? completion.exerciseTitle)
        .accessibilityValue(completion.completedAt.formatted(.dateTime.hour().minute()))
        .accessibilityHint("Shows the saved exercise details")
        .accessibilityIdentifier("weeklyExerciseBlock.\(completion.id)")
    }
}

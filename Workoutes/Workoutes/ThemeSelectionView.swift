import SwiftUI

struct ThemeSelectionView: View {
    @AppStorage("appAccentColor") private var accentColorRawValue = ThemeColor.primary.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var centeredTheme: ThemeColor?

    private var selectedTheme: ThemeColor { ThemeColor.resolve(accentColorRawValue) }

    var body: some View {
        GeometryReader { geometry in
            let labelSpace: CGFloat = dynamicTypeSize.isAccessibilitySize ? 130 : 80
            let width = max(80, min(geometry.size.width * 0.72,
                                    (geometry.size.height - labelSpace - 64) * 140 / 272))
            let height = width * 272 / 140

            VStack(spacing: 12) {
                Spacer(minLength: 16)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: -width * 0.22) {
                            ForEach(ThemeColor.allCases) { theme in
                                themeOption(theme, width: width) {
                                    withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.86)) {
                                        accentColorRawValue = theme.rawValue
                                        centeredTheme = theme
                                        proxy.scrollTo(theme.id, anchor: .center)
                                    }
                                }
                                .scrollTransition(reduceMotion ? .identity : .interactive.threshold(.centered), axis: .horizontal) { content, phase in
                                    content.scaleEffect(phase.isIdentity ? 1 : 0.86)
                                }
                                .zIndex(theme == centeredTheme ? 1 : 0)
                                .id(theme.id)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, 16)
                    }
                    .contentMargins(.horizontal, (geometry.size.width - width) / 2, for: .scrollContent)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne, anchor: .center))
                    .scrollPosition(id: $centeredTheme, anchor: .center)
                    .frame(height: height + labelSpace)
                    .onScrollGeometryChange(for: CGSize.self) { $0.contentSize } action: { _, size in
                        // Wait for measured scroll targets before positioning the active theme.
                        guard size.width > 0 else { return }
                        centeredTheme = selectedTheme
                        proxy.scrollTo(selectedTheme.id, anchor: .center)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(ThemeColor.allCases) { theme in
                        Circle()
                            .fill(theme == centeredTheme ? Color.primary.opacity(0.7) : Color.primary.opacity(0.18))
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
                Spacer(minLength: 24)
            }
        }
        .transparentNavigationChrome()
        .defaultScreenBackground()
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeOption(_ theme: ThemeColor, width: CGFloat, select: @escaping () -> Void) -> some View {
        let isSelected = theme == selectedTheme
        let accent = Color(hex: theme.hex(for: colorScheme))
        return Button(action: select) {
            VStack(spacing: 16) {
                ThemeExercisePreview(theme: theme)
                    .scaleEffect((width - 8) / 140)
                    .frame(width: width - 8, height: (width - 8) * 272 / 140)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 12, y: 6)
                    .padding(4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(isSelected ? accent : Color.primary.opacity(0.1),
                                          lineWidth: isSelected ? 2.5 : 1)
                    }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent)
                        .opacity(isSelected ? 1 : 0)
                    Text(theme.name)
                        .foregroundStyle(Color.primary)
                }
                .font(.title3.weight(isSelected ? .semibold : .regular))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.name)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("themeOption.\(theme.rawValue)")
    }
}

/// A decorative Exercises silhouette, without exercise data or interactive controls.
struct ThemeExercisePreview: View {
    let theme: ThemeColor
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color { Color(hex: theme.hex(for: colorScheme)) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.18))
                    .frame(width: 61, height: 7)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(height: 25)

            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.07), lineWidth: 0.5)
                    }
                    .overlay(alignment: .topTrailing) {
                        ExerciseStatusSymbol(status: .done, accentColor: accent)
                            .scaleEffect(0.5)
                            .frame(width: 22, height: 22)
                            .padding(5)
                    }
                    .frame(height: 51)
            }

            Spacer(minLength: 0)
            HStack(spacing: 0) {
                ForEach(["house.fill", "list.clipboard.fill", "dumbbell.fill", "gearshape.fill"], id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(symbol == "dumbbell.fill" ? accent : Color.primary.opacity(0.35))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 25)
            .background(Color.primary.opacity(0.05), in: Capsule())
        }
        .padding(10)
        .frame(width: 140, height: 272)
        .background { ThemeBackgroundGradient(theme: theme) }
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack { ThemeSelectionView() }
}

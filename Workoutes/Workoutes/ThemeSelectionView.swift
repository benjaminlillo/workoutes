import SwiftUI

struct ThemeSelectionView: View {
    @AppStorage("appAccentColor") private var accentColorRawValue = ThemeColor.primary.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var selectedTheme: ThemeColor { ThemeColor.resolve(accentColorRawValue) }

    var body: some View {
        List {
            Section("Themes") {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(ThemeColor.allCases) { theme in
                                themeOption(theme)
                                    .id(theme.id)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(16)
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                    .onAppear { proxy.scrollTo(selectedTheme.id, anchor: .center) }
                }
                .listRowInsets(EdgeInsets())
                .subtleFormRowBorder()
            }
        }
        .transparentNavigationChrome()
        .defaultScreenBackground()
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeOption(_ theme: ThemeColor) -> some View {
        let isSelected = theme == selectedTheme
        let accent = Color(hex: theme.hex(for: colorScheme))
        return Button {
            accentColorRawValue = theme.rawValue
        } label: {
            VStack(spacing: 12) {
                ThemeExercisePreview(theme: theme)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(isSelected ? accent : Color.primary.opacity(0.1),
                                          lineWidth: isSelected ? 2.5 : 1)
                    }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(accent)
                    }
                    Text(theme.name)
                        .foregroundStyle(Color.primary)
                }
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 148)
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

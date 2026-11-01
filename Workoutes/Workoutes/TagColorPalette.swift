import SwiftUI

/// Stable semantic IDs with a coordinated seven-color variant for each app theme.
enum TagColorPalette: String, CaseIterable, Identifiable {
    case blue, teal, violet, coral, orange, gold, red

    var id: Self { self }
    var hex: String { hex(for: .indigo) }
    var color: Color { Color(hex: hex) }

    func hex(for theme: ThemeColor) -> String {
        let colors: [String]
        switch theme {
        case .indigo: colors = ["5B92E5", "50B3B1", "A484D1", "EA8581", "EDAA67", "DFB75C", "CC5E55"]
        case .electricRush: colors = ["627FE7", "47BFC7", "A48BD9", "E78197", "EAAA72", "CFCA66", "DA5E58"]
        case .sunsetPop: colors = ["7B8ED0", "68ADA5", "B285CD", "E97D91", "EBA365", "D9B55D", "D45A50"]
        case .ultravolt: colors = ["758BD8", "62B3A0", "9D7BD4", "DB86A0", "DDA36B", "C2BE65", "C95B58"]
        case .cobaltHeat: colors = ["5E87CC", "53A6AB", "9388C8", "DC8181", "EAA06A", "D2B56A", "CE625A"]
        case .cherryIce: colors = ["6999CF", "5FBFBA", "B08EC7", "DC7A98", "E5A28C", "D6B971", "CA5557"]
        case .midnightGold: colors = ["6B8CB5", "68A7A4", "A296BF", "D38E88", "D9A573", "D9BA69", "B96960"]
        }
        switch self {
        case .blue: return colors[0]
        case .teal: return colors[1]
        case .violet: return colors[2]
        case .coral: return colors[3]
        case .orange: return colors[4]
        case .gold: return colors[5]
        case .red: return colors[6]
        }
    }

    var name: String {
        switch self {
        case .blue: String(localized: "Blue")
        case .teal: String(localized: "Teal")
        case .violet: String(localized: "Violet")
        case .coral: String(localized: "Coral")
        case .orange: String(localized: "Orange")
        case .gold: String(localized: "Gold")
        case .red: String(localized: "Red")
        }
    }
}

struct TagColorPicker: View {
    @AppStorage("appAccentColor") private var themeRawValue = ThemeColor.indigo.rawValue
    @Binding var selection: TagColorSelection
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            TagColorSuggestions(selection: $selection)
                .padding(.vertical, 6)
        } label: {
            HStack {
                Text("Color").foregroundStyle(.primary)
                Spacer()
                Circle().fill(Color(hex: selection.hex(for: ThemeColor.resolve(themeRawValue))))
                    .overlay { Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5) }
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("tagColorDisclosure")
    }
}

struct TagColorSuggestions: View {
    @AppStorage("appAccentColor") private var themeRawValue = ThemeColor.indigo.rawValue
    private var theme: ThemeColor { ThemeColor.resolve(themeRawValue) }
    @Binding var selection: TagColorSelection

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { choices }
                .fixedSize(horizontal: true, vertical: false)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                choices
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("tagColorSuggestions")
    }

    @ViewBuilder
    private var choices: some View {
        ForEach(TagColorPalette.allCases) { option in
            let isSelected = selection.paletteID == option.rawValue
            Button {
                selection = .suggested(option)
            } label: {
                Circle().fill(Color(hex: option.hex(for: theme)))
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black.opacity(0.78))
                        }
                    }
                    .frame(width: 30, height: 30)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(option.name)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("tagSuggestedColor-\(option.rawValue)")
        }

        ColorPicker("Custom Color", selection: Binding(
            get: { Color(hex: selection.hex(for: theme)) },
            set: { selection = .custom($0.toHex()) }
        ))
            .labelsHidden()
            .frame(width: 44, height: 44)
            .accessibilityIdentifier("tagCustomColor")
            .simultaneousGesture(TapGesture().onEnded {
                selection = .custom(selection.hex(for: theme))
            })
    }
}

/// A custom color can equal a suggested HEX without becoming theme-dependent.
struct TagColorSelection: Equatable {
    var paletteID: String?
    var customHex: String

    static func suggested(_ color: TagColorPalette) -> Self {
        Self(paletteID: color.rawValue, customHex: color.hex)
    }

    static func custom(_ hex: String) -> Self { Self(paletteID: nil, customHex: hex) }

    func hex(for theme: ThemeColor) -> String {
        paletteID.flatMap(TagColorPalette.init(rawValue:))?.hex(for: theme) ?? customHex
    }
}

@MainActor
enum TagColorSynchronization {
    /// Keep the existing rendered HEX cache current so every tag consumer and Live Activity
    /// receives the same colors. Nil and unknown IDs are never inferred from a matching HEX.
    static func apply(_ theme: ThemeColor, to tags: [Tag]) {
        for tag in tags {
            guard let id = tag.paletteColorID, let palette = TagColorPalette(rawValue: id) else { continue }
            let hex = palette.hex(for: theme)
            if tag.colorHex != hex { tag.colorHex = hex }
        }
    }
}

extension ExerciseCompletionSnapshot.Tag {
    func resolvedColorHex(for theme: ThemeColor) -> String {
        paletteColorID.flatMap(TagColorPalette.init(rawValue:))?.hex(for: theme) ?? colorHex
    }
}

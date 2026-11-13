import SwiftData

@MainActor
enum DefaultTagConfiguration {
    struct Group {
        let icon: MuscleIcon
        let color: TagColorPalette
        let tags: [MuscleIcon]
    }

    static let groups: [Group] = [
        .init(icon: .chest, color: .blue, tags: [.upperChest, .middleChest, .lowerChest]),
        .init(icon: .back, color: .teal, tags: [.trapezius, .upperBack, .lats, .obliques, .lowerBack]),
        .init(icon: .shoulders, color: .orange, tags: [.anteriorDeltoid, .lateralDeltoid, .posteriorDeltoid]),
        .init(icon: .biceps, color: .violet, tags: [.bicepsLongHead, .bicepsShortHead]),
        .init(icon: .triceps, color: .coral, tags: [.tricepsLongHead, .tricepsLateralHead, .tricepsMedialHead]),
        .init(icon: .forearms, color: .teal, tags: [.forearmFlexors, .forearmExtensors, .brachioradialis]),
        .init(icon: .lowerBody, color: .red, tags: MuscleIcon.allCases.filter { $0.group == .lowerBody }),
        .init(icon: .core, color: .gold,
              tags: [.abdominals, .externalObliques, .internalObliques, .transverseAbdominis, .lowerBack])
    ]

    static func install(in context: ModelContext, theme: ThemeColor) throws {
        guard try context.fetchCount(FetchDescriptor<TagGroup>()) == 0,
              try context.fetchCount(FetchDescriptor<Tag>()) == 0 else { return }

        // Save unrelated edits before starting the all-or-nothing insert.
        if context.hasChanges { try context.save() }
        do {
            try context.transaction {
                var tags: [MuscleIcon: Tag] = [:]
                for definition in groups {
                    let color = definition.color
                    let members = definition.tags.map { icon in
                        if let existing = tags[icon] { return existing }
                        let tag = Tag(name: icon.name, colorHex: color.hex(for: theme),
                                      iconName: icon.rawValue, paletteColorID: color.rawValue)
                        context.insert(tag)
                        tags[icon] = tag
                        return tag
                    }
                    context.insert(TagGroup(name: definition.icon.name, colorHex: color.hex(for: theme),
                                            paletteColorID: color.rawValue, iconName: definition.icon.rawValue,
                                            tags: members))
                }
            }
        } catch {
            context.rollback()
            throw error
        }
    }
}

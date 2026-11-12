import SwiftData
import SwiftUI

struct TagManagementView: View {
    @Query(sort: \TagGroup.name) private var groups: [TagGroup]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @AppStorage("appAccentColor") private var accentColor = ThemeColor.indigo.rawValue
    @State private var editor: Editor?

    private enum Editor: Identifiable {
        case group(TagGroup?)
        case tag(Tag?)

        var id: String {
            switch self {
            case .group(let group): "group-" + (group?.stableID ?? "new")
            case .tag(let tag): "tag-" + (tag?.stableID ?? "new")
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                sectionHeader("Groups", add: "New Group") { editor = .group(nil) }
                ForEach(groups) { group in
                    TagGroupCard(group: group, theme: ThemeColor.resolve(accentColor),
                                 edit: { editor = .group(group) },
                                 editTag: { editor = .tag($0) })
                }

                sectionHeader("All Tags", add: "New Tag") { editor = .tag(nil) }
                    .padding(.top, 8)
                ForEach(tags) { tag in
                    EditableTagRow(tag: tag) { editor = .tag(tag) }
                        .padding(.horizontal, 16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(16)
        }
        .defaultScreenBackground()
        .transparentNavigationChrome()
        .navigationTitle("Manage Tags")
        .sheet(item: $editor) { editor in
            switch editor {
            case .group(let group): ManageTagGroupSheet(group: group)
            case .tag(let tag): ManageTagSheet(editingTag: tag)
            }
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey, add: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Button(action: action) {
                Label(add, systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .frame(minHeight: 44)
        }
    }
}

private struct TagGroupCard: View {
    let group: TagGroup
    let theme: ThemeColor
    let edit: () -> Void
    let editTag: (Tag) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        TagGroupMark(icon: group.muscleIcon, color: Color(hex: group.resolvedColorHex(for: theme)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.name).font(.headline)
                            Text("\(group.tags.count) tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(expanded ? Text("Expanded") : Text("Collapsed"))

                Button(action: edit) {
                    Image(systemName: "pencil")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Edit Group"))
                .accessibilityValue(group.name)
            }

            if expanded {
                Divider().padding(.vertical, 6)
                if group.tags.isEmpty {
                    Button("Select Tags", action: edit)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    ForEach(group.tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { tag in
                        EditableTagRow(tag: tag) { editTag(tag) }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct EditableTagRow: View {
    let tag: Tag
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            HStack {
                TagLabel(tag: tag)
                Spacer()
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TagGroupMark: View {
    let icon: MuscleIcon?
    let color: Color

    var body: some View {
        Group {
            if let icon {
                MuscleIconView(icon: icon, color: color)
                    .frame(width: 34, height: 34)
            } else {
                Circle().fill(color).frame(width: 16, height: 16)
            }
        }
        .frame(width: 42, height: 42)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }
}

private struct ManageTagGroupSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var tags: [Tag]
    @AppStorage("appAccentColor") private var accentColor = ThemeColor.indigo.rawValue

    let group: TagGroup?
    @State private var name: String
    @State private var colorSelection: TagColorSelection
    @State private var icon: MuscleIcon?
    @State private var selectedTags: Set<PersistentIdentifier>
    @State private var colorsExpanded = false
    @State private var confirmingDeletion = false

    init(group: TagGroup?) {
        self.group = group
        _name = State(initialValue: group?.name ?? "")
        _colorSelection = State(initialValue: group.map {
            TagColorSelection(paletteID: $0.paletteColorID, customHex: $0.colorHex)
        } ?? .suggested(.blue))
        _icon = State(initialValue: group?.muscleIcon)
        _selectedTags = State(initialValue: group?.tagIDs ?? [])
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var colorHex: String { colorSelection.hex(for: ThemeColor.resolve(accentColor)) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    TextField("Name", text: $name)
                    TagColorPicker(selection: $colorSelection, isExpanded: $colorsExpanded)
                    NavigationLink {
                        MuscleIconPicker(selection: $icon, color: Color(hex: colorHex))
                    } label: {
                        HStack {
                            Text("Muscle Icon")
                            Spacer()
                            if let icon {
                                MuscleIconView(icon: icon, color: Color(hex: colorHex))
                                    .frame(width: 24, height: 24)
                                    .accessibilityHidden(true)
                            }
                            Text(icon?.name ?? String(localized: "None"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Tags") {
                    if tags.isEmpty {
                        Text("No Tags").foregroundStyle(.secondary)
                    }
                    ForEach(tags) { tag in
                        Toggle(isOn: membership(of: tag)) { TagLabel(tag: tag) }
                    }
                }
                if group != nil {
                    Section {
                        Button("Delete Group", role: .destructive) { confirmingDeletion = true }
                    }
                }
            }
            .navigationTitle(group == nil ? "New Group" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .transparentNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog("Delete Group?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
                Button("Delete Group", role: .destructive) {
                    if let group { modelContext.delete(group) }
                    dismiss()
                }
            }
        }
    }

    private func membership(of tag: Tag) -> Binding<Bool> {
        let id = tag.persistentModelID
        return Binding(get: { selectedTags.contains(id) }, set: { selected in
            if selected { selectedTags.insert(id) }
            else { selectedTags.remove(id) }
        })
    }

    private func save() {
        let edited = group ?? TagGroup(name: trimmedName, colorHex: colorHex)
        edited.name = trimmedName
        edited.colorHex = colorHex
        edited.paletteColorID = colorSelection.paletteID
        edited.iconName = icon?.rawValue
        edited.tags = tags.filter { selectedTags.contains($0.persistentModelID) }
        if group == nil { modelContext.insert(edited) }
        dismiss()
    }
}

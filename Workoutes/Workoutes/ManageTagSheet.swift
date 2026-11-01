import SwiftUI
import SwiftData

struct ManageTagSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var editingTag: Tag?
    
    @State private var name: String = ""
    @AppStorage("appAccentColor") private var themeRawValue = ThemeColor.indigo.rawValue
    @State private var colorSelection: TagColorSelection = .suggested(.blue)
    private var theme: ThemeColor { ThemeColor.resolve(themeRawValue) }
    private var color: Color { Color(hex: colorSelection.hex(for: theme)) }
    @State private var isColorExpanded = false
    @State private var selectedIcon: MuscleIcon?

    init(editingTag: Tag? = nil) {
        self.editingTag = editingTag
        _name = State(initialValue: editingTag?.name ?? "")
        _colorSelection = State(initialValue: editingTag.map {
            TagColorSelection(paletteID: $0.paletteColorID, customHex: $0.colorHex)
        } ?? .suggested(.blue))
        _selectedIcon = State(initialValue: editingTag?.muscleIcon)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tag Details")) {
                    TextField("Name", text: $name)
                        .subtleFormRowShadow(.first)
                    TagColorPicker(selection: $colorSelection, isExpanded: $isColorExpanded)
                        .subtleFormRowShadow(.middle)
                    NavigationLink {
                        MuscleIconPicker(selection: $selectedIcon, color: color)
                    } label: {
                        HStack {
                            Text("Muscle Icon").foregroundStyle(.primary)
                            Spacer()
                            if let selectedIcon {
                                MuscleIconView(icon: selectedIcon, color: color)
                                    .frame(width: 24, height: 24)
                            }
                            Text(selectedIcon?.name ?? String(localized: "None")).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("tagMuscleIcon")
                    .subtleFormRowShadow(.last)
                }
                
                if let editingTag = editingTag {
                    Section {
                        Button("Delete Tag", role: .destructive) {
                            modelContext.delete(editingTag)
                            dismiss()
                        }
                        .subtleFormRowShadow()
                    }
                }
            }
            .transparentNavigationChrome()
            .navigationTitle(editingTag == nil ? "New Tag" : "Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func save() {
        if let tag = editingTag {
            tag.name = name
            tag.colorHex = colorSelection.hex(for: theme)
            tag.paletteColorID = colorSelection.paletteID
            tag.iconName = selectedIcon?.rawValue
        } else {
            let newTag = Tag(name: name, colorHex: colorSelection.hex(for: theme), iconName: selectedIcon?.rawValue,
                             paletteColorID: colorSelection.paletteID)
            modelContext.insert(newTag)
        }
        dismiss()
    }
}

import SwiftUI
import SwiftData

struct ManageTagSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var editingTag: Tag?
    
    @State private var name: String = ""
    @State private var color: Color = .blue
    @State private var selectedIcon: MuscleIcon?

    init(editingTag: Tag? = nil) {
        self.editingTag = editingTag
        _name = State(initialValue: editingTag?.name ?? "")
        _color = State(initialValue: editingTag.map { Color(hex: $0.colorHex) } ?? .blue)
        _selectedIcon = State(initialValue: editingTag?.muscleIcon)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tag Details")) {
                    TextField("Name", text: $name)
                        .subtleFormRowShadow(.first)
                    ColorPicker("Color", selection: $color)
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
                            Text(selectedIcon?.name ?? "None").foregroundStyle(.secondary)
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
            tag.colorHex = color.toHex()
            tag.iconName = selectedIcon?.rawValue
        } else {
            let newTag = Tag(name: name, colorHex: color.toHex(), iconName: selectedIcon?.rawValue)
            modelContext.insert(newTag)
        }
        dismiss()
    }
}

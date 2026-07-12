import SwiftUI
import SwiftData

struct ManageTagSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var editingTag: Tag?
    
    @State private var name: String = ""
    @State private var color: Color = .blue
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tag Details")) {
                    TextField("Name", text: $name)
                    ColorPicker("Color", selection: $color)
                }
                
                if let editingTag = editingTag {
                    Section {
                        Button("Delete Tag", role: .destructive) {
                            modelContext.delete(editingTag)
                            dismiss()
                        }
                    }
                }
            }
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
            .onAppear {
                if let tag = editingTag {
                    name = tag.name
                    color = Color(hex: tag.colorHex)
                }
            }
        }
    }
    
    private func save() {
        if let tag = editingTag {
            tag.name = name
            tag.colorHex = color.toHex()
        } else {
            let newTag = Tag(name: name, colorHex: color.toHex())
            modelContext.insert(newTag)
        }
        dismiss()
    }
}

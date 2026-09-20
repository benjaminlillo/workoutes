import SwiftData
import SwiftUI

struct SessionTemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionController.self) private var session
    @Query(sort: \SessionTemplate.createdAt) private var templates: [SessionTemplate]

    private var template: SessionTemplate? { templates.first }

    var body: some View {
        List {
            if let template {
                Section {
                    ForEach(template.blocks.sorted { $0.order < $1.order }) { block in
                        NavigationLink {
                            SessionBlockEditorView(block: block)
                        } label: {
                            HStack {
                                Label(block.name, systemImage: block.kind == .exercise ? "figure.strengthtraining.traditional" : "timer")
                                Spacer()
                                Text(block.kind == .rest
                                     ? shortDuration(block.restDuration)
                                     : "\(shortDuration(block.restDuration)) between sets")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove { source, destination in move(source, destination, in: template) }
                    .onDelete { offsets in delete(offsets, from: template) }
                } footer: {
                    Text("When an exercise becomes active, its sets and the configured rest between them are added to the current exercise block. Rest blocks advance automatically.")
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Session Template")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Add Block", systemImage: "plus") {
                    Button("Exercise", systemImage: "figure.strengthtraining.traditional") { add(.exercise) }
                    Button("Rest", systemImage: "timer") { add(.rest) }
                }
            }
        }
        .onAppear { session.ensureDefaultTemplate() }
    }

    private func add(_ kind: SessionBlockKind) {
        guard let template else { return }
        let block = SessionTemplateBlock(
            order: template.blocks.count,
            name: kind == .exercise ? "Exercise" : "Rest",
            kind: kind,
            restDuration: 60
        )
        template.blocks.append(block)
        try? modelContext.save()
    }

    private func move(_ source: IndexSet, _ destination: Int, in template: SessionTemplate) {
        var ordered = template.blocks.sorted { $0.order < $1.order }
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, block) in ordered.enumerated() { block.order = index }
        template.blocks = ordered
        try? modelContext.save()
    }

    private func delete(_ offsets: IndexSet, from template: SessionTemplate) {
        var ordered = template.blocks.sorted { $0.order < $1.order }
        for index in offsets.sorted(by: >) {
            let block = ordered.remove(at: index)
            modelContext.delete(block)
        }
        for (index, block) in ordered.enumerated() { block.order = index }
        template.blocks = ordered
        try? modelContext.save()
    }

    private func shortDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct SessionBlockEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: SessionTemplateBlock

    private var minutes: Binding<Int> {
        Binding(
            get: { Int(block.restDuration) / 60 },
            set: { value in
                let seconds = value == 60 ? 0 : Int(block.restDuration) % 60
                block.restDuration = TimeInterval(max(5, min(3600, value * 60 + seconds)))
                try? modelContext.save()
            }
        )
    }
    private var seconds: Binding<Int> {
        Binding(
            get: { Int(block.restDuration) % 60 },
            set: { value in
                block.restDuration = TimeInterval(max(5, min(3600, Int(block.restDuration) / 60 * 60 + value)))
                try? modelContext.save()
            }
        )
    }

    var body: some View {
        Form {
            TextField("Block Name", text: $block.name)
                .onSubmit { try? modelContext.save() }
            LabeledContent("Type", value: block.kind == .exercise ? "Exercise" : "Rest")
            Section(block.kind == .exercise ? "Rest Between Sets" : "Duration") {
                HStack {
                    Picker("Minutes", selection: minutes) {
                        ForEach(0...60, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    Picker("Seconds", selection: seconds) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { Text("\($0) sec").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .disabled(minutes.wrappedValue == 60)
                }
                .frame(height: 180)
            }
        }
        .navigationTitle("Edit Block")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
    }
}

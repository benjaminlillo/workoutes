import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingFileImporter = false
    @State private var showCopiedAlert = false
    @State private var showingSuccessAlert = false
    @State private var importError: String?
    
    let aiPrompt = """
    Please convert the provided workout exercises into a JSON format strictly following this structure:
    
    {
      "workouts": [{ "id": "uuid", "name": "string" }],
      "tags": [{ "id": "uuid", "name": "string", "colorHex": "string" }],
      "exercises": [
        {
          "id": "uuid",
          "title": "string",
          "subtitle": "string",
          "details": "string",
          "numberOfSets": 0,
          "reps": 0,
          "increaseLoadNextTime": false,
          "isDone": false,
          "weight": 0.0,
          "workouts": [{ "id": "uuid" }],
          "tags": [{ "id": "uuid" }]
        }
      ]
    }
    
    Ensure all objects are linked by matching 'id's. Use valid UUIDs for all 'id' fields. Output ONLY valid JSON without markdown wrapping if possible.
    """
    
    var body: some View {
        Form {
            Section(header: Text("JSON Format Requirements")) {
                Text("To import workouts, your JSON file must follow a strict relational structure linking workouts, tags, and exercises by unique IDs.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text("Reimporting a file updates catalog items by ID without creating duplicates. Exercise history is imported automatically when included.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("AI Assistant Prompt")) {
                Text("Copy this prompt and send it to ChatGPT, Claude, or Gemini along with your text-based routines. The AI will format your routines into the exact JSON format required by Workoutes.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    UIPasteboard.general.string = aiPrompt
                    showCopiedAlert = true
                }) {
                    HStack {
                        Text("Copy AI Prompt")
                        Spacer()
                        Image(systemName: "doc.on.doc")
                    }
                }
                .alert("Prompt Copied!", isPresented: $showCopiedAlert) {
                    Button("OK", role: .cancel) { }
                }
            }
            
            Section {
                Button(action: { showingFileImporter = true }) {
                    HStack {
                        Text("Select JSON File")
                        Spacer()
                        Image(systemName: "folder")
                    }
                }
            }
        }
        .transparentNavigationChrome()
        .defaultScreenBackground()
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importData(from: url)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Import Successful", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Your data has been successfully imported.")
        }
        .alert("Import Failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "") }
    }
    
    private func importData(from url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        
        do {
            let data = try Data(contentsOf: url)
            try DataBackup.importData(data, into: modelContext)
            showingSuccessAlert = true
        } catch {
            importError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ImportDataView()
            .modelContainer(for: Workout.self, inMemory: true)
    }
}

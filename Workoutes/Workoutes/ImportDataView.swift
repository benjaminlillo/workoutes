import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingFileImporter = false
    @State private var showCopiedAlert = false
    @State private var showingSuccessAlert = false
    
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
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
        .alert("Import Successful", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Your data has been successfully imported.")
        }
    }
    
    private func importData(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Permission denied to access file.")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let importedData = try decoder.decode(ExportDataDTO.self, from: data)
            
            var workoutIDMap: [String: Workout] = [:]
            var tagIDMap: [String: Tag] = [:]
            
            for wDTO in importedData.workouts {
                let workout = Workout(name: wDTO.name)
                modelContext.insert(workout)
                workoutIDMap[wDTO.id] = workout
            }
            
            for tDTO in importedData.tags {
                let tag = Tag(name: tDTO.name, colorHex: tDTO.colorHex)
                modelContext.insert(tag)
                tagIDMap[tDTO.id] = tag
            }
            
            for exDTO in importedData.exercises {
                let exercise = WorkoutExercise(
                    title: exDTO.title,
                    subtitle: exDTO.subtitle,
                    details: exDTO.details,
                    numberOfSets: exDTO.numberOfSets,
                    reps: exDTO.reps,
                    increaseLoadNextTime: exDTO.increaseLoadNextTime,
                    weight: exDTO.weight,
                    isDone: exDTO.isDone
                )
                
                let exerciseWorkouts = exDTO.workouts.compactMap { ref in
                    workoutIDMap[ref.id]
                }
                exercise.workouts = exerciseWorkouts
                
                let exerciseTags = exDTO.tags.compactMap { ref in
                    tagIDMap[ref.id]
                }
                exercise.tags = exerciseTags
                
                modelContext.insert(exercise)
            }
            
            showingSuccessAlert = true
        } catch {
            print("Error importing JSON: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        ImportDataView()
            .modelContainer(for: Workout.self, inMemory: true)
    }
}

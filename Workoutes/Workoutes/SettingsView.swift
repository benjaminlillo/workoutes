import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportDataDTO: Codable {
    var workouts: [WorkoutDTO]
    var exercises: [WorkoutExerciseDTO]
    var tags: [TagDTO]
}

struct WorkoutDTO: Codable {
    var id: String
    var name: String
}

struct TagDTO: Codable {
    var id: String
    var name: String
    var colorHex: String
}

struct WorkoutExerciseDTO: Codable {
    var id: String
    var title: String
    var subtitle: String
    var details: String
    var numberOfSets: Int
    var reps: Int
    var increaseLoadNextTime: Bool
    var isDone: Bool
    var weight: Double
    var workouts: [EntityRefDTO]
    var tags: [EntityRefDTO]
}

struct EntityRefDTO: Codable {
    var id: String
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    @Query private var workouts: [Workout]
    @Query private var exercises: [WorkoutExercise]
    @Query private var tags: [Tag]
    @State private var shareURL: IdentifiableURL?
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Appearance")) {
                    Picker("Accent Color", selection: $accentColorRawValue) {
                        ForEach(ThemeColor.allCases) { theme in
                            Text(theme.name)
                                .tag(theme.rawValue)
                        }
                    }
                }
                
                Section(header: Text("Data")) {
                    Button(action: exportData) {
                        HStack {
                            Text("Export Data (JSON)")
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    
                    NavigationLink(destination: ImportDataView()) {
                        HStack {
                            Text("Import Data (JSON)")
                            Spacer()
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $shareURL) { identifiableURL in
                ShareSheet(items: [identifiableURL.url])
            }
        }
    }
    
    private func exportData() {
        var workoutIDMap: [PersistentIdentifier: String] = [:]
        var tagIDMap: [PersistentIdentifier: String] = [:]
        
        let workoutsDTO = workouts.map { w -> WorkoutDTO in
            let id = UUID().uuidString
            workoutIDMap[w.persistentModelID] = id
            return WorkoutDTO(id: id, name: w.name)
        }
        
        let tagsDTO = tags.map { t -> TagDTO in
            let id = UUID().uuidString
            tagIDMap[t.persistentModelID] = id
            return TagDTO(id: id, name: t.name, colorHex: t.colorHex)
        }
        
        let exercisesDTO = exercises.map { ex -> WorkoutExerciseDTO in
            let workoutRefs = ex.workouts.compactMap { w -> EntityRefDTO? in
                guard let id = workoutIDMap[w.persistentModelID] else { return nil }
                return EntityRefDTO(id: id)
            }
            
            let tagRefs = ex.tags.compactMap { t -> EntityRefDTO? in
                guard let id = tagIDMap[t.persistentModelID] else { return nil }
                return EntityRefDTO(id: id)
            }
            
            return WorkoutExerciseDTO(
                id: UUID().uuidString,
                title: ex.title,
                subtitle: ex.subtitle,
                details: ex.details,
                numberOfSets: ex.numberOfSets,
                reps: ex.reps,
                increaseLoadNextTime: ex.increaseLoadNextTime,
                isDone: ex.isDone,
                weight: ex.weight,
                workouts: workoutRefs,
                tags: tagRefs
            )
        }
        
        let exportData = ExportDataDTO(
            workouts: workoutsDTO,
            exercises: exercisesDTO,
            tags: tagsDTO
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(exportData)
            
            let tempDir = FileManager.default.temporaryDirectory
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let dateStr = formatter.string(from: Date())
            let fileURL = tempDir.appendingPathComponent("workoutes_export_\(dateStr).json")
            
            try data.write(to: fileURL)
            self.shareURL = IdentifiableURL(url: fileURL)
        } catch {
            print("Error encoding JSON: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Workout.self, inMemory: true)
}

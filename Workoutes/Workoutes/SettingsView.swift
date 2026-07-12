import SwiftUI
import SwiftData

struct WorkoutDTO: Codable {
    var name: String
    var exercises: [WorkoutExerciseDTO]
}

struct WorkoutExerciseDTO: Codable {
    var title: String
    var subtitle: String
    var details: String
    var numberOfSets: Int
    var reps: Int
    var increaseLoadNextTime: Bool
    var isDone: Bool
    var weight: Double
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
    @State private var shareURL: IdentifiableURL?
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Data")) {
                    Button(action: exportData) {
                        HStack {
                            Text("Export Data (JSON)")
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
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
        // Mapeamos a DTOs en el hilo principal para evitar problemas de concurrencia con SwiftData
        let dtos = workouts.map { workout in
            WorkoutDTO(
                name: workout.name,
                exercises: workout.exercises.map { ex in
                    WorkoutExerciseDTO(
                        title: ex.title,
                        subtitle: ex.subtitle,
                        details: ex.details,
                        numberOfSets: ex.numberOfSets,
                        reps: ex.reps,
                        increaseLoadNextTime: ex.increaseLoadNextTime,
                        isDone: ex.isDone,
                        weight: ex.weight
                    )
                }
            )
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(dtos)
            
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

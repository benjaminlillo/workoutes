import SwiftUI
import SwiftData

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
    @Environment(\.modelContext) private var modelContext
    @State private var shareURL: IdentifiableURL?
    @State private var showingExportOptions = false
    @State private var exportError: String?
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .metric

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Accent Color", selection: $accentColorRawValue) {
                        ForEach(ThemeColor.allCases) { theme in Text(theme.name).tag(theme.rawValue) }
                    }
                }
                Section("Units") {
                    Picker("Weight Unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in Text(unit.name).tag(unit) }
                    }
                }
                Section("Data") {
                    Button { showingExportOptions = true } label: {
                        HStack { Text("Export Data (JSON)"); Spacer(); Image(systemName: "square.and.arrow.up") }
                    }
                    NavigationLink(destination: ImportDataView()) {
                        HStack { Text("Import Data (JSON)"); Spacer(); Image(systemName: "square.and.arrow.down") }
                    }
                }
            }
            .transparentNavigationChrome()
            .defaultScreenBackground()
            .navigationTitle("Settings")
            .sheet(item: $shareURL) { ShareSheet(items: [$0.url]) }
            .confirmationDialog("Include exercise history?", isPresented: $showingExportOptions, titleVisibility: .visible) {
                Button("Include History") { exportData(includeHistory: true) }
                Button("Catalog Only") { exportData(includeHistory: false) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Active exercise sessions are never exported.")
            }
            .alert("Export Failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private func exportData(includeHistory: Bool) {
        do {
            let data = try DataBackup.export(from: modelContext, includeHistory: includeHistory)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("workoutes_export_\(UUID().uuidString).json")
            try data.write(to: url, options: .atomic)
            shareURL = IdentifiableURL(url: url)
        } catch { exportError = error.localizedDescription }
    }
}

#Preview {
    SettingsView().modelContainer(for: Workout.self, inMemory: true)
}

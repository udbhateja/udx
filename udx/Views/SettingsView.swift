import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Define custom UTType for our backup files
extension UTType {
    static let udxBackup = UTType(filenameExtension: "udxbackup") ?? UTType.data
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var majorMuscles: [MajorMuscle]
    @StateObject private var exportImportService = ExportImportService.shared
    
    @State private var showAddMajorMuscle = false
    @State private var showAddMinorMuscle = false
    @State private var newMajorMuscleName = ""
    @State private var newMinorMuscleName = ""
    @State private var selectedMajorMuscle: MajorMuscle?
    
    // Export/Import states
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var exportedFileURL: URL?
    @State private var showImportConfirmation = false
    @State private var importURL: URL?
    @State private var showRestartRequired = false
    
    var body: some View {
        NavigationStack {
            List {
                // Data Management Section
                Section("Data Management") {
                    // Export
                    Button(action: { Task { await exportData() } }) {
                        HStack {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                            Spacer()
                            if exportImportService.isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(exportImportService.isExporting)
                    
                    // Import
                    Button(action: { showImportPicker = true }) {
                        HStack {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                            Spacer()
                            if exportImportService.isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(exportImportService.isImporting)
                    
                    // Auto Export Status
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Daily Auto-Export", isOn: .constant(true))
                            .disabled(true)
                        
                        if let lastExport = exportImportService.lastExportDate {
                            Text("Last export: \(lastExport.formatted())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let lastImport = exportImportService.lastImportDate {
                            Text("Last import: \(lastImport.formatted())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Muscle Management Section
                Section("Muscles") {
                    NavigationLink {
                        manageMusclesView
                    } label: {
                        Text("Manage Muscles")
                    }
                }
                
                // API Keys Section (placeholder for future Gemini integration)
                Section("API Keys") {
                    NavigationLink {
                        apiKeysView
                    } label: {
                        Text("Gemini API Key")
                    }
                }
            }
            .navigationTitle("Settings")
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.udxBackup],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        importURL = url
                        showImportConfirmation = true
                    }
                case .failure(let error):
                    alertTitle = "Import Error"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
            .alert("Import Data", isPresented: $showImportConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Import", role: .destructive) {
                    if let url = importURL {
                        Task { await importData(from: url) }
                    }
                }
            } message: {
                Text("This will replace all existing data. Are you sure you want to continue?")
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .alert("Restart Required", isPresented: $showRestartRequired) {
                Button("OK") { exit(0) }
            } message: {
                Text("The app needs to restart to load the imported data. The app will now close.")
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportedFileURL {
                    ShareSheet(url: url)
                }
            }
        }
        .task {
            // Check for automatic export on view appear
            await exportImportService.performAutomaticExportIfNeeded()
        }
    }
    
    // MARK: - Export/Import Methods
    
    private func exportData() async {
        do {
            let url = try await exportImportService.exportData()
            exportedFileURL = url
            showExportSheet = true
        } catch {
            alertTitle = "Export Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    private func importData(from url: URL) async {
        do {
            guard let container = try? modelContext.container else {
                throw ImportError.storeNotFound
            }
            
            try await exportImportService.importData(from: url, modelContainer: container)
            alertTitle = "Import Successful"
            alertMessage = "Data imported successfully. The app needs to restart to load the new data."
            showAlert = true
            showRestartRequired = true
        } catch {
            alertTitle = "Import Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    // MARK: - Sub Views
    
    private var apiKeysView: some View {
        Form {
            Section {
                SecureField("Gemini API Key", text: .constant(""))
                    .disabled(true)
                Text("Gemini integration coming soon")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var manageMusclesView: some View {
        List {
            Section("Major Muscles") {
                ForEach(majorMuscles) { muscle in
                    NavigationLink(muscle.name) {
                        minorMusclesView(for: muscle)
                    }
                }
                .onDelete(perform: deleteMajorMuscles)
                
                Button("Add Major Muscle") {
                    showAddMajorMuscle = true
                }
            }
        }
        .navigationTitle("Manage Muscles")
        .sheet(isPresented: $showAddMajorMuscle) {
            addMajorMuscleView
        }
    }
    
    private func minorMusclesView(for majorMuscle: MajorMuscle) -> some View {
        List {
            Section("Minor Muscles for \(majorMuscle.name)") {
                if let minorMuscles = majorMuscle.minorMuscles {
                    ForEach(minorMuscles) { muscle in
                        Text(muscle.name)
                    }
                    .onDelete { indices in
                        deleteMinorMuscles(indices: indices, from: majorMuscle)
                    }
                }
                
                Button("Add Minor Muscle") {
                    selectedMajorMuscle = majorMuscle
                    showAddMinorMuscle = true
                }
            }
        }
        .navigationTitle(majorMuscle.name)
        .sheet(isPresented: $showAddMinorMuscle) {
            addMinorMuscleView
        }
    }
    
    private var addMajorMuscleView: some View {
        NavigationStack {
            Form {
                TextField("Major Muscle Name", text: $newMajorMuscleName)
                
                Button("Save") {
                    if (!newMajorMuscleName.isEmpty) {
                        let muscle = MajorMuscle(name: newMajorMuscleName)
                        modelContext.insert(muscle)
                        newMajorMuscleName = ""
                        
                        // Explicitly save changes
                        try? modelContext.save()
                        SwiftDataManager.shared.saveContext()
                        
                        showAddMajorMuscle = false
                    }
                }
                .disabled(newMajorMuscleName.isEmpty)
            }
            .navigationTitle("Add Major Muscle")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showAddMajorMuscle = false
                    }
                }
            }
        }
    }
    
    private var addMinorMuscleView: some View {
        NavigationStack {
            Form {
                TextField("Minor Muscle Name", text: $newMinorMuscleName)
                
                Button("Save") {
                    if (!newMinorMuscleName.isEmpty), let majorMuscle = selectedMajorMuscle {
                        let minorMuscle = MinorMuscle(name: newMinorMuscleName, majorMuscle: majorMuscle)
                        modelContext.insert(minorMuscle)
                        
                        if (majorMuscle.minorMuscles == nil) {
                            majorMuscle.minorMuscles = [minorMuscle]
                        } else {
                            majorMuscle.minorMuscles?.append(minorMuscle)
                        }
                        
                        newMinorMuscleName = ""
                        
                        // Explicitly save changes
                        try? modelContext.save()
                        SwiftDataManager.shared.saveContext()
                        
                        showAddMinorMuscle = false
                    }
                }
                .disabled(newMinorMuscleName.isEmpty)
            }
            .navigationTitle("Add Minor Muscle")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showAddMinorMuscle = false
                    }
                }
            }
        }
    }
    
    private func deleteMajorMuscles(at offsets: IndexSet) {
        // Save IDs before modifying the array
        let muscleIDs = offsets.map { majorMuscles[$0].id }
        
        // Wait until the next run loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task {
                await DeleteHelper.deleteMajorMuscles(withIDs: muscleIDs, using: self.modelContext)
            }
        }
    }
    
    private func deleteMinorMuscles(indices: IndexSet, from majorMuscle: MajorMuscle) {
        // Safe copy of minor muscles
        guard let minorMuscles = majorMuscle.minorMuscles else { return }
        
        // Save IDs before modifying
        let muscleIDs = indices.map { minorMuscles[$0].id }
        let majorMuscleID = majorMuscle.id
        
        // Wait until the next run loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task {
                await DeleteHelper.deleteMinorMuscles(withIDs: muscleIDs, fromMajorMuscleID: majorMuscleID, using: self.modelContext)
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Add to the DeleteHelper actor
class DeleteHelper {
    static func deleteMajorMuscles(withIDs ids: [PersistentIdentifier], using context: ModelContext) {
        do {
            for id in ids {
                // Find the major muscle by ID
                let descriptor = FetchDescriptor<MajorMuscle>(predicate: #Predicate { $0.id == id })
                guard let majorMuscle = try context.fetch(descriptor).first else { continue }
                
                // Clear relations before deleting
                let minorMuscles = majorMuscle.minorMuscles ?? []
                majorMuscle.minorMuscles = nil
                majorMuscle.exercises = nil
                
                try context.save()
                
                // Delete minor muscles
                for minorMuscle in minorMuscles {
                    minorMuscle.exercises = nil
                    minorMuscle.majorMuscle = nil
                    context.delete(minorMuscle)
                }
                
                try context.save()
                
                // Delete the major muscle
                context.delete(majorMuscle)
                try context.save()
            }
        } catch {
            print("Error deleting major muscles: \(error)")
        }
    }
    
    static func deleteMinorMuscles(withIDs ids: [PersistentIdentifier], fromMajorMuscleID majorID: PersistentIdentifier, using context: ModelContext) {
        do {
            // Find the major muscle
            let majorDescriptor = FetchDescriptor<MajorMuscle>(predicate: #Predicate { $0.id == majorID })
            guard let majorMuscle = try context.fetch(majorDescriptor).first else { return }
            
            // Process each minor muscle
            for id in ids {
                let descriptor = FetchDescriptor<MinorMuscle>(predicate: #Predicate { $0.id == id })
                guard let minorMuscle = try context.fetch(descriptor).first else { continue }
                
                // Update the major muscle's minorMuscles array
                if var minorMuscles = majorMuscle.minorMuscles {
                    majorMuscle.minorMuscles = minorMuscles.filter { $0.id != minorMuscle.id }
                }
                
                // Clear relationships
                minorMuscle.exercises = nil
                minorMuscle.majorMuscle = nil
                
                try context.save()
                
                // Delete the minor muscle
                context.delete(minorMuscle)
                try context.save()
            }
        } catch {
            print("Error deleting minor muscles: \(error)")
        }
    }
}

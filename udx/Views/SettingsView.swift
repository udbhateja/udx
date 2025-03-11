import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var majorMuscles: [MajorMuscle]
    
    @State private var showAddMajorMuscle = false
    @State private var showAddMinorMuscle = false
    @State private var newMajorMuscleName = ""
    @State private var newMinorMuscleName = ""
    @State private var selectedMajorMuscle: MajorMuscle?
    
    var body: some View {
        NavigationStack {
            List {
                Section("Muscles") {
                    NavigationLink {
                        manageMusclesView
                    } label: {
                        Text("Manage Muscles")
                    }
                }
                
                // Add other settings sections here as needed
            }
            .navigationTitle("Settings")
        }
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

// Add to the DeleteHelper actor
actor DeleteHelper {
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

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
                    if !newMajorMuscleName.isEmpty {
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
                    if !newMinorMuscleName.isEmpty, let majorMuscle = selectedMajorMuscle {
                        let minorMuscle = MinorMuscle(name: newMinorMuscleName, majorMuscle: majorMuscle)
                        modelContext.insert(minorMuscle)
                        
                        if majorMuscle.minorMuscles == nil {
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
        for index in offsets {
            let muscle = majorMuscles[index]
            modelContext.delete(muscle)
        }
        
        // Explicitly save changes
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
    }
    
    private func deleteMinorMuscles(indices: IndexSet, from majorMuscle: MajorMuscle) {
        guard var minorMuscles = majorMuscle.minorMuscles else { return }
        
        for index in indices {
            let muscle = minorMuscles[index]
            modelContext.delete(muscle)
        }
        
        // Explicitly save changes
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
    }
}

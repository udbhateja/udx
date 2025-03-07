import SwiftUI
import SwiftData
import PhotosUI

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var majorMuscles: [MajorMuscle]
    
    @State private var name = ""
    @State private var details = ""
    @State private var videoURLString = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    @State private var selectedMajorMuscles: Set<MajorMuscle> = []
    @State private var selectedMinorMuscles: Set<MinorMuscle> = []
    @State private var availableMinorMuscles: [MinorMuscle] = []
    
    var formIsValid: Bool {
        !name.isEmpty && !selectedMajorMuscles.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Information") {
                    TextField("Exercise Name", text: $name)
                    
                    VStack(alignment: .leading) {
                        Text("Major Muscle Groups")
                            .font(.headline)
                            .padding(.top, 5)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(majorMuscles) { muscle in
                                    Toggle(muscle.name, isOn: Binding(
                                        get: { selectedMajorMuscles.contains(muscle) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedMajorMuscles.insert(muscle)
                                            } else {
                                                selectedMajorMuscles.remove(muscle)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.button)
                                    .buttonStyle(.bordered)
                                    .tint(selectedMajorMuscles.contains(muscle) ? .blue : .gray)
                                }
                            }
                        }
                        .padding(.bottom, 5)
                    }
                    
                    if !availableMinorMuscles.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Minor Muscles")
                                .font(.headline)
                                .padding(.top, 5)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(availableMinorMuscles) { muscle in
                                        Toggle(muscle.name, isOn: Binding(
                                            get: { selectedMinorMuscles.contains(muscle) },
                                            set: { isSelected in
                                                if isSelected {
                                                    selectedMinorMuscles.insert(muscle)
                                                } else {
                                                    selectedMinorMuscles.remove(muscle)
                                                }
                                            }
                                        ))
                                        .toggleStyle(.button)
                                        .buttonStyle(.bordered)
                                        .tint(selectedMinorMuscles.contains(muscle) ? .blue : .gray)
                                    }
                                }
                            }
                            .padding(.bottom, 5)
                        }
                    }
                }
                
                Section("Details") {
                    TextEditor(text: $details)
                        .frame(height: 100)
                }
                
                Section("Video Reference") {
                    TextField("YouTube URL", text: $videoURLString)
                }
                
                Section("Exercise Image") {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Select an image", systemImage: "photo")
                    }
                    
                    if let selectedImageData,
                       let uiImage = UIImage(data: selectedImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .disabled(!formIsValid)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
            .onChange(of: selectedMajorMuscles) { _, _ in
                updateAvailableMinorMuscles()
            }
        }
    }
    
    private func updateAvailableMinorMuscles() {
        var minors: [MinorMuscle] = []
        
        for major in selectedMajorMuscles {
            if let muscles = major.minorMuscles {
                minors.append(contentsOf: muscles)
            }
        }
        
        availableMinorMuscles = minors
        
        // Remove selected minor muscles that are no longer available
        selectedMinorMuscles = selectedMinorMuscles.filter { minorMuscle in
            availableMinorMuscles.contains { $0.id == minorMuscle.id }
        }
    }
    
    private func saveExercise() {
        guard !selectedMajorMuscles.isEmpty else { return }
        
        // Create primary major and minor muscles for string compatibility
        let primaryMajorMuscle = selectedMajorMuscles.first!
        let primaryMinorMuscle = selectedMinorMuscles.first
        
        let exercise = Exercise(
            name: name,
            details: details,
            muscleGroup: primaryMajorMuscle.name,
            minorMuscle: primaryMinorMuscle?.name ?? ""
        )
        
        // Set additional properties
        exercise.imageData = selectedImageData
        if !videoURLString.isEmpty {
            exercise.videoURL = URL(string: videoURLString)
        }
        
        // Set multiple muscle relationships
        exercise.majorMuscles = Array(selectedMajorMuscles)
        if !selectedMinorMuscles.isEmpty {
            exercise.minorMuscles = Array(selectedMinorMuscles)
        }
        
        modelContext.insert(exercise)
        
        // Update relationships for major muscles
        for muscle in selectedMajorMuscles {
            if muscle.exercises == nil {
                muscle.exercises = [exercise]
            } else {
                muscle.exercises?.append(exercise)
            }
        }
        
        // Update relationships for minor muscles
        for muscle in selectedMinorMuscles {
            if muscle.exercises == nil {
                muscle.exercises = [exercise]
            } else {
                muscle.exercises?.append(exercise)
            }
        }
        
        // Explicitly save changes
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
        
        dismiss()
    }
}

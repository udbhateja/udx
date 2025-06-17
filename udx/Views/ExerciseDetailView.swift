import SwiftUI
import SwiftData
import PhotosUI

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var exercise: Exercise
    @State private var isEditing = false
    @State private var showingLogView = false
    
    // For editing
    @State private var editedName: String
    @State private var editedDetails: String
    @State private var editedVideoURL: String
    @State private var selectedMajorMuscles: Set<MajorMuscle> = []
    @State private var selectedMinorMuscles: Set<MinorMuscle> = []
    
    // For image editing
    @State private var selectedItem: PhotosPickerItem?
    @State private var editedImageData: Data?
    @State private var showImageOptions = false
    
    // For selecting muscles when editing
    @Query private var majorMuscles: [MajorMuscle]
    @State private var availableMinorMuscles: [MinorMuscle] = []
    
    init(exercise: Exercise) {
        self._exercise = State(initialValue: exercise)
        self._editedName = State(initialValue: exercise.name)
        self._editedDetails = State(initialValue: exercise.details)
        self._editedVideoURL = State(initialValue: exercise.videoURL?.absoluteString ?? "")
        self._editedImageData = State(initialValue: exercise.imageData)
        
        var majorSet = Set<MajorMuscle>()
        if let majors = exercise.majorMuscles {
            for muscle in majors {
                majorSet.insert(muscle)
            }
        } else if let major = exercise.majorMuscleRef {
            majorSet.insert(major)
        }
        self._selectedMajorMuscles = State(initialValue: majorSet)
        
        var minorSet = Set<MinorMuscle>()
        if let minors = exercise.minorMuscles {
            for muscle in minors {
                minorSet.insert(muscle)
            }
        } else if let minor = exercise.minorMuscleRef {
            minorSet.insert(minor)
        }
        self._selectedMinorMuscles = State(initialValue: minorSet)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Display image if available
                if isEditing {
                    imageEditSection
                } else if let imageData = exercise.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                }
                
                if isEditing {
                    editForm
                } else {
                    displayView
                }
                
                Divider()
                
                // Log button
                Button("Log Workout") {
                    showingLogView = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                
                Divider()
                
                exerciseHistorySection
            }
            .padding()
        }
        .navigationTitle(isEditing ? "Edit Exercise" : exercise.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
            }
            
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Reset edited values
                        resetEditedValues()
                        isEditing = false
                    }
                }
            }
        }
        .onChange(of: selectedMajorMuscles) { _, newValue in
            updateAvailableMinorMuscles()
        }
        .confirmationDialog(
            "Image Options",
            isPresented: $showImageOptions,
            titleVisibility: .visible
        ) {
            Button("Choose from library") {
                // Show photo picker
                selectedItem = nil
            }
            
            Button("Remove image", role: .destructive) {
                editedImageData = nil
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    editedImageData = data
                }
            }
        }
        .sheet(isPresented: $showingLogView) {
            ExerciseLogView(exercise: exercise)
        }
    }
    
    private var imageEditSection: some View {
        VStack {
            if let imageData = editedImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                
                Button("Change Image") {
                    showImageOptions = true
                }
                .buttonStyle(.bordered)
            } else {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack {
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        Text("Add Image")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var displayView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("Muscle Groups")
                    .font(.headline)
                Text(exercise.allMajorMuscleNames)
                    .padding(.leading)
            }
            
            if !exercise.allMinorMuscleNames.isEmpty {
                Group {
                    Text("Minor Muscles")
                        .font(.headline)
                    Text(exercise.allMinorMuscleNames)
                        .padding(.leading)
                }
            }
            
            if !exercise.details.isEmpty {
                Group {
                    Text("Details")
                        .font(.headline)
                    Text(exercise.details)
                        .padding(.leading)
                }
            }
            
            if let url = exercise.videoURL {
                Group {
                    Text("Video Reference")
                        .font(.headline)
                    Link(url.absoluteString, destination: url)
                        .padding(.leading)
                }
            }
        }
    }
    
    private var editForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Exercise Name", text: $editedName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Text("Major Muscle Groups")
                .font(.headline)
            
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
            
            if !availableMinorMuscles.isEmpty {
                Text("Minor Muscles")
                    .font(.headline)
                
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
            }
            
            Text("Video URL")
                .font(.headline)
            
            TextField("YouTube URL", text: $editedVideoURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Text("Details")
                .font(.headline)
            
            TextEditor(text: $editedDetails)
                .frame(height: 100)
                .border(Color.gray.opacity(0.2))
                .cornerRadius(5)
        }
    }
    
    private var exerciseHistorySection: some View {
        VStack(alignment: .leading) {
            Text("Exercise History")
                .font(.headline)
            
            if let history = exercise.workoutHistory, !history.isEmpty {
                ForEach(history.sorted(by: { $0.date > $1.date })) { log in
                    VStack(alignment: .leading) {
                        Text(log.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(log.sets) sets × \(log.reps) reps at \(String(format: "%.1f", log.weight)) kg")
                            .font(.body)
                        
                        if let notes = log.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            } else {
                Text("No workout history yet")
                    .foregroundColor(.secondary)
                    .padding()
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
    }
    
    private func resetEditedValues() {
        editedName = exercise.name
        editedDetails = exercise.details
        editedVideoURL = exercise.videoURL?.absoluteString ?? ""
        editedImageData = exercise.imageData
        
        var majorSet = Set<MajorMuscle>()
        if let majors = exercise.majorMuscles {
            for muscle in majors {
                majorSet.insert(muscle)
            }
        } else if let major = exercise.majorMuscleRef {
            majorSet.insert(major)
        }
        selectedMajorMuscles = majorSet
        
        var minorSet = Set<MinorMuscle>()
        if let minors = exercise.minorMuscles {
            for muscle in minors {
                minorSet.insert(muscle)
            }
        } else if let minor = exercise.minorMuscleRef {
            minorSet.insert(minor)
        }
        selectedMinorMuscles = minorSet
        
        updateAvailableMinorMuscles()
    }
    
    private func saveChanges() {
        // Update exercise properties
        exercise.name = editedName
        exercise.details = editedDetails
        exercise.imageData = editedImageData
        
        // Update video URL
        if !editedVideoURL.isEmpty {
            exercise.videoURL = URL(string: editedVideoURL)
        } else {
            exercise.videoURL = nil
        }
        
        // Update major muscles
        if selectedMajorMuscles.isEmpty {
            exercise.muscleGroup = "Uncategorized"
            exercise.majorMuscles = nil
        } else {
            let selectedArray = Array(selectedMajorMuscles)
            exercise.majorMuscles = selectedArray
            exercise.muscleGroup = selectedArray.first?.name ?? "Uncategorized"
            
            // Update the exercises array for each major muscle
            for muscle in selectedArray {
                if muscle.exercises == nil {
                    muscle.exercises = [exercise]
                } else if !muscle.exercises!.contains(where: { $0.id == exercise.id }) {
                    muscle.exercises!.append(exercise)
                }
            }
        }
        
        // Update minor muscles
        if selectedMinorMuscles.isEmpty {
            exercise.minorMuscle = ""
            exercise.minorMuscles = nil
        } else {
            let selectedArray = Array(selectedMinorMuscles)
            exercise.minorMuscles = selectedArray
            exercise.minorMuscle = selectedArray.first?.name ?? ""
            
            // Update the exercises array for each minor muscle
            for muscle in selectedArray {
                if muscle.exercises == nil {
                    muscle.exercises = [exercise]
                } else if !muscle.exercises!.contains(where: { $0.id == exercise.id }) {
                    muscle.exercises!.append(exercise)
                }
            }
        }
        
        // Explicitly save changes
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
    }
}

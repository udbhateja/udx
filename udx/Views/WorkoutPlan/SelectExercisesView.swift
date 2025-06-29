import SwiftUI
import SwiftData

struct SelectExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var plan: WorkoutPlan
    @Query private var allExercises: [Exercise]
    @Query private var majorMuscles: [MajorMuscle]
    
    @State private var selectedExercises = Set<Exercise>()
    @State private var searchText = ""
    @State private var selectedMuscleFilter: MajorMuscle? = nil
    
    var onSave: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                // Muscle filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button(action: { selectedMuscleFilter = nil }) {
                            Text("All")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedMuscleFilter == nil ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedMuscleFilter == nil ? .white : .primary)
                                .cornerRadius(20)
                        }
                        
                        ForEach(majorMuscles) { muscle in
                            Button(action: { selectedMuscleFilter = muscle }) {
                                Text(muscle.name)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedMuscleFilter?.id == muscle.id ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedMuscleFilter?.id == muscle.id ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                
                List {
                    if !selectedExercises.isEmpty {
                        Section("Selected Exercises (\(selectedExercises.count))") {
                            ForEach(Array(selectedExercises).sorted(by: { $0.name < $1.name }), id: \.id) { exercise in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(exercise.name)
                                            .font(.headline)
                                        HStack {
                                            Text(exercise.exerciseType.rawValue)
                                                .font(.caption)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(backgroundForType(exercise.exerciseType))
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                            
                                            Text(exercise.allMajorMuscleNames)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedExercises.remove(exercise)
                                }
                            }
                        }
                    }
                    
                    Section("Available Exercises") {
                        ForEach(filteredExercises, id: \.id) { exercise in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                        .font(.headline)
                                    HStack {
                                        Text(exercise.exerciseType.rawValue)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(backgroundForType(exercise.exerciseType))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                        
                                        Text(exercise.allMajorMuscleNames)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedExercises.contains(where: { $0.id == exercise.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleExerciseSelection(exercise)
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search exercises")
            }
            .navigationTitle("Select Exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSelectedExercises()
                    }
                    .disabled(selectedExercises.isEmpty)
                }
            }
            .onAppear {
                loadExistingExercises()
            }
        }
    }
    
    private var filteredExercises: [Exercise] {
        var filtered = allExercises
        
        // Filter by selected muscle if any
        if let selectedMuscle = selectedMuscleFilter {
            filtered = filtered.filter { exercise in
                if let majorMuscles = exercise.majorMuscles {
                    return majorMuscles.contains { muscle in
                        muscle.id == selectedMuscle.id
                    }
                }
                return exercise.muscleGroup == selectedMuscle.name
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.allMajorMuscleNames.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by name
        return filtered.sorted(by: { $0.name < $1.name })
    }
    
    private func toggleExerciseSelection(_ exercise: Exercise) {
        if selectedExercises.contains(where: { $0.id == exercise.id }) {
            selectedExercises.remove(exercise)
        } else {
            selectedExercises.insert(exercise)
        }
    }
    
    private func loadExistingExercises() {
        // Pre-select exercises that are already in the workout plan
        if let existingExercises = plan.exercises {
            for plannedExercise in existingExercises {
                selectedExercises.insert(plannedExercise.exercise)
            }
        }
    }
    
    private func saveSelectedExercises() {
        // Remove any existing exercises
        if let currentExercises = plan.exercises {
            for exercise in currentExercises {
                modelContext.delete(exercise)
            }
        }
        
        // Create planned exercises
        var plannedExercises: [PlannedExercise] = []
        
        for (index, exercise) in selectedExercises.enumerated() {
            let plannedExercise = PlannedExercise(
                exercise: exercise,
                order: index
            )
            
            // Set default targets based on exercise type
            switch exercise.exerciseType {
            case .weight:
                plannedExercise.targetSets = 3
                plannedExercise.targetReps = 10
                // Set suggested weight based on last workout
                if let lastWorkout = exercise.workoutHistory?.sorted(by: { $0.date > $1.date }).first {
                    plannedExercise.targetWeight = lastWorkout.weight * 1.05
                }
                
            case .cardio:
                plannedExercise.targetSets = 1
                if exercise.cardioMetric == .time || exercise.cardioMetric == .both {
                    plannedExercise.targetDuration = 1800 // Default 30 minutes
                }
                if exercise.cardioMetric == .distance || exercise.cardioMetric == .both {
                    plannedExercise.targetDistance = 5.0 // Default 5km
                }
                
            case .bodyweight:
                plannedExercise.targetSets = 3
                plannedExercise.targetReps = 15
                
            case .flexibility:
                plannedExercise.targetSets = 1
                plannedExercise.targetDuration = 300 // Default 5 minutes
            }
            
            plannedExercises.append(plannedExercise)
            modelContext.insert(plannedExercise)
        }
        
        plan.exercises = plannedExercises
        
        // Save immediately
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
        
        // Call the completion handler if provided
        if let onSave = onSave {
            onSave()
        } else {
            dismiss()
        }
    }
    
    private func backgroundForType(_ type: ExerciseType) -> Color {
        switch type {
        case .weight:
            return .blue
        case .cardio:
            return .orange
        case .bodyweight:
            return .green
        case .flexibility:
            return .purple
        }
    }
}

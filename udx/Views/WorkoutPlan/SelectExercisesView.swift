import SwiftUI
import SwiftData

struct SelectExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var plan: WorkoutPlan
    @Query private var allExercises: [Exercise]
    
    @State private var selectedExercises = Set<Exercise>()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if let targetMuscles = plan.targetMuscles, !targetMuscles.isEmpty {
                    targetMusclesView(muscles: targetMuscles)
                }
                
                List {
                    Section("Selected Exercises (\(selectedExercises.count))") {
                        ForEach(Array(selectedExercises), id: \.id) { exercise in
                            HStack {
                                Text(exercise.name)
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
                    
                    Section("Available Exercises") {
                        ForEach(filteredExercises, id: \.id) { exercise in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                        .font(.headline)
                                    Text(exercise.muscleGroup)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
        }
    }
    
    private func targetMusclesView(muscles: [MajorMuscle]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(muscles) { muscle in
                    Text(muscle.name)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .onTapGesture {
                            selectExercisesForMuscle(muscle)
                        }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private var filteredExercises: [Exercise] {
        var filtered = allExercises
        
        // Filter by target muscles if any are selected
        if let targetMuscles = plan.targetMuscles, !targetMuscles.isEmpty {
            filtered = filtered.filter { exercise in
                if let majorMuscles = exercise.majorMuscles {
                    return majorMuscles.contains { muscle in
                        targetMuscles.contains { $0.id == muscle.id }
                    }
                }
                return targetMuscles.contains { $0.name == exercise.muscleGroup }
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered
    }
    
    private func toggleExerciseSelection(_ exercise: Exercise) {
        if selectedExercises.contains(where: { $0.id == exercise.id }) {
            selectedExercises.remove(exercise)
        } else {
            selectedExercises.insert(exercise)
        }
    }
    
    private func selectExercisesForMuscle(_ muscle: MajorMuscle) {
        if let muscleExercises = muscle.exercises {
            for exercise in muscleExercises {
                selectedExercises.insert(exercise)
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
                order: index,
                targetSets: 3,
                targetReps: 10
            )
            
            // Set suggested weight based on last workout
            if let lastWorkout = exercise.workoutHistory?.sorted(by: { $0.date > $1.date }).first {
                plannedExercise.targetWeight = lastWorkout.weight * 1.05
            }
            
            plannedExercises.append(plannedExercise)
            modelContext.insert(plannedExercise)
        }
        
        plan.exercises = plannedExercises
        
        // Save immediately
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
        
        dismiss()
    }
}

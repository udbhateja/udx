import SwiftUI
import SwiftData

struct ExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @Query private var majorMuscles: [MajorMuscle]
    @State private var showingAddExercise = false
    @State private var searchText = ""
    @State private var selectedMajorMuscle: MajorMuscle?
    
    var filteredExercises: [Exercise] {
        var filtered = exercises
        
        if let selected = selectedMajorMuscle {
            filtered = filtered.filter { exercise in
                // Check if the exercise has the selected major muscle
                if let majorMuscles = exercise.majorMuscles {
                    return majorMuscles.contains { $0.id == selected.id }
                } else {
                    return exercise.muscleGroup == selected.name
                }
            }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered
    }
    
    var groupedExercises: [String: [Exercise]] {
        Dictionary(grouping: filteredExercises) { $0.muscleGroup }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Muscle group filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button(action: { selectedMajorMuscle = nil }) {
                            Text("All")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedMajorMuscle == nil ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedMajorMuscle == nil ? .white : .primary)
                                .cornerRadius(20)
                        }
                        
                        ForEach(majorMuscles) { muscle in
                            Button(action: { selectedMajorMuscle = muscle }) {
                                Text(muscle.name)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedMajorMuscle?.id == muscle.id ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedMajorMuscle?.id == muscle.id ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                exerciseList
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddExercise = true }) {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
            }
        }
    }
    
    private var exerciseList: some View {
        List {
            ForEach(groupedExercises.keys.sorted(), id: \.self) { group in
                if let exercises = groupedExercises[group] {
                    Section(header: Text(group)) {
                        ForEach(exercises, id: \.id) { exercise in
                            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(exercise.name)
                                            .font(.headline)
                                        Spacer()
                                        Text(exercise.exerciseType.rawValue)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(backgroundForType(exercise.exerciseType))
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    if !exercise.allMinorMuscleNames.isEmpty {
                                        Text(exercise.allMinorMuscleNames)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            deleteExercises(exercises, at: indexSet)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
    }
    
    private func deleteExercises(_ exercises: [Exercise], at offsets: IndexSet) {
        for index in offsets {
            let exercise = exercises[index]
            
            // Delete related ExerciseLog entries
            if let workoutHistory = exercise.workoutHistory {
                for log in workoutHistory {
                    modelContext.delete(log)
                }
            }
            
            // Find and delete any PlannedExercise entries that use this exercise
            let descriptor = FetchDescriptor<PlannedExercise>()
            if let plannedExercises = try? modelContext.fetch(descriptor) {
                for plannedExercise in plannedExercises {
                    if plannedExercise.exercise.id == exercise.id {
                        // Delete associated WorkoutSet entries first
                        if let logs = plannedExercise.logs {
                            for log in logs {
                                modelContext.delete(log)
                            }
                        }
                        modelContext.delete(plannedExercise)
                    }
                }
            }
            
            // Remove exercise from muscle relationships
            if let majorMuscles = exercise.majorMuscles {
                for muscle in majorMuscles {
                    muscle.exercises?.removeAll { $0.id == exercise.id }
                }
            }
            
            if let minorMuscles = exercise.minorMuscles {
                for muscle in minorMuscles {
                    muscle.exercises?.removeAll { $0.id == exercise.id }
                }
            }
            
            // Finally delete the exercise
            modelContext.delete(exercise)
        }
        
        // Save immediately after deletion
        do {
            try modelContext.save()
            SwiftDataManager.shared.saveContext()
        } catch {
            print("Error deleting exercise: \(error)")
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

struct ExercisesView_Previews: PreviewProvider {
    static var previews: some View {
        ExercisesView()
    }
}

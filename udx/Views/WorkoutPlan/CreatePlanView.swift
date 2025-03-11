import SwiftUI
import SwiftData

struct CreatePlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var majorMuscles: [MajorMuscle]
    
    @State private var planName = "Workout"
    @State private var planDate = Date()
    @State private var planNotes = ""
    @State private var selectedMuscles = Set<MajorMuscle>()
    @State private var useAI = false
    @State private var generatingWithAI = false
    @State private var showingExerciseSelection = false
    @State private var createdPlan: WorkoutPlan?
    
    var formIsValid: Bool {
        !planName.isEmpty && !selectedMuscles.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    TextField("Workout Name", text: $planName)
                    DatePicker("Date", selection: $planDate, displayedComponents: .date)
                    TextEditor(text: $planNotes)
                        .frame(height: 100)
                }
                
                Section("Target Muscles") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(majorMuscles) { muscle in
                                Toggle(muscle.name, isOn: Binding(
                                    get: { selectedMuscles.contains(muscle) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedMuscles.insert(muscle)
                                        } else {
                                            selectedMuscles.remove(muscle)
                                        }
                                    }
                                ))
                                .toggleStyle(.button)
                                .buttonStyle(.bordered)
                                .tint(selectedMuscles.contains(muscle) ? .blue : .gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Toggle("Generate with AI", isOn: $useAI)
                        .onChange(of: useAI) { _, newValue in
                            if newValue {
                                // Reset selected muscles if using AI
                                selectedMuscles = Set(majorMuscles.prefix(3))
                            }
                        }
                } footer: {
                    Text("AI will generate a workout plan targeting the selected muscle groups")
                }
            }
            .navigationTitle("Create Workout")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        createWorkoutPlan()
                    }
                    .disabled(!formIsValid)
                }
            }
            .sheet(isPresented: $showingExerciseSelection) {
                if let plan = createdPlan {
                    SelectExercisesView(plan: plan)
                }
            }
            .overlay {
                if generatingWithAI {
                    ProgressView("Generating workout with AI...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
    }
    
    private func createWorkoutPlan() {
        let plan = WorkoutPlan(date: planDate, name: planName, notes: planNotes)
        plan.targetMuscles = Array(selectedMuscles)
        modelContext.insert(plan)
        
        if useAI {
            generateWithAI(plan: plan)
        } else {
            createdPlan = plan
            showingExerciseSelection = true
        }
        
        // Save immediately
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
    }
    
    private func generateWithAI(plan: WorkoutPlan) {
        generatingWithAI = true
        
        // In a real app, this would call the Gemini API
        // For now, we'll simulate it with a delay and template data
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            simulateAIWorkoutGeneration(for: plan)
            generatingWithAI = false
            dismiss()
        }
    }
    
    private func simulateAIWorkoutGeneration(for plan: WorkoutPlan) {
        // Get exercises for each selected muscle
        var exercises: [Exercise] = []
        
        for muscle in selectedMuscles {
            if let muscleExercises = muscle.exercises {
                // Take up to 2 exercises per muscle
                let muscleSelection = Array(muscleExercises.prefix(2))
                exercises.append(contentsOf: muscleSelection)
            }
        }
        
        // If we have no exercises, nothing to do
        guard !exercises.isEmpty else {
            return
        }
        
        // Create planned exercises
        var plannedExercises: [PlannedExercise] = []
        
        for (index, exercise) in exercises.enumerated() {
            let plannedExercise = PlannedExercise(
                exercise: exercise,
                order: index,
                targetSets: Int.random(in: 3...4),
                targetReps: Int.random(in: 8...12)
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
    }
}

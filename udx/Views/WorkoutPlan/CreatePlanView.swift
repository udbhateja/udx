import SwiftUI
import SwiftData

struct CreatePlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    
    @State private var planName = "Workout"
    @State private var planDate = Date()
    @State private var planNotes = ""
    @State private var useAI = false
    @State private var generatingWithAI = false
    @State private var showingExerciseSelection = false
    @State private var createdPlan: WorkoutPlan?
    @State private var geminiAPIKey = ""
    
    // Edit mode support
    var existingPlan: WorkoutPlan? = nil
    var isEditMode: Bool { existingPlan != nil }
    
    var formIsValid: Bool {
        !planName.isEmpty
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
                
                if !isEditMode {
                    Section {
                        Toggle("Generate with AI", isOn: $useAI)
                        
                        if useAI {
                            SecureField("Gemini API Key", text: $geminiAPIKey)
                                .textContentType(.password)
                        }
                    } footer: {
                        Text("AI will generate a complete workout plan based on your exercise history and progressive overload principles")
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit Workout" : "Create Workout")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditMode ? "Save" : "Next") {
                        if isEditMode {
                            updateWorkoutPlan()
                        } else {
                            createWorkoutPlan()
                        }
                    }
                    .disabled(!formIsValid || (useAI && geminiAPIKey.isEmpty))
                }
            }
            .sheet(isPresented: $showingExerciseSelection) {
                if let plan = createdPlan {
                    SelectExercisesView(plan: plan) {
                        // Dismiss both sheets when exercises are saved
                        dismiss()
                    }
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
            .onAppear {
                setupForEditing()
                loadGeminiAPIKey()
            }
        }
    }
    
    private func createWorkoutPlan() {
        let plan = WorkoutPlan(date: planDate, name: planName, notes: planNotes)
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
        
        // Save API key if provided
        if !geminiAPIKey.isEmpty {
            UserDefaults.standard.set(geminiAPIKey, forKey: "GeminiAPIKey")
        }
        
        // In a real app, this would call the Gemini API
        // For now, we'll simulate it with a delay and template data
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            simulateAIWorkoutGeneration(for: plan)
            generatingWithAI = false
            dismiss()
        }
    }
    
    private func simulateAIWorkoutGeneration(for plan: WorkoutPlan) {
        // Simulate AI generation by creating a balanced workout
        // In production, this would analyze exercise history and apply progressive overload
        
        var plannedExercises: [PlannedExercise] = []
        
        // Group exercises by major muscle
        var exercisesByMuscle: [String: [Exercise]] = [:]
        for exercise in exercises {
            let muscleGroup = exercise.allMajorMuscleNames
            if exercisesByMuscle[muscleGroup] == nil {
                exercisesByMuscle[muscleGroup] = []
            }
            exercisesByMuscle[muscleGroup]?.append(exercise)
        }
        
        // Select 4-6 exercises for a balanced workout
        let targetExerciseCount = Int.random(in: 4...6)
        var selectedExercises: [Exercise] = []
        
        // Try to get variety from different muscle groups
        for (_, muscleExercises) in exercisesByMuscle.prefix(targetExerciseCount) {
            if let randomExercise = muscleExercises.randomElement() {
                selectedExercises.append(randomExercise)
            }
        }
        
        // Create planned exercises with progressive overload
        for (index, exercise) in selectedExercises.enumerated() {
            let plannedExercise = PlannedExercise(
                exercise: exercise,
                order: index
            )
            
            // Set targets based on exercise type
            switch exercise.exerciseType {
            case .weight:
                plannedExercise.targetSets = Int.random(in: 3...4)
                plannedExercise.targetReps = Int.random(in: 8...12)
                
                // Progressive overload from last workout
                if let lastWorkout = exercise.workoutHistory?.sorted(by: { $0.date > $1.date }).first {
                    plannedExercise.targetWeight = lastWorkout.weight * 1.05 // 5% increase
                }
                
            case .cardio:
                plannedExercise.targetSets = 1
                if exercise.cardioMetric == .time || exercise.cardioMetric == .both {
                    plannedExercise.targetDuration = TimeInterval(Int.random(in: 20...40) * 60) // 20-40 minutes
                }
                if exercise.cardioMetric == .distance || exercise.cardioMetric == .both {
                    plannedExercise.targetDistance = Double.random(in: 3...10) // 3-10 km
                }
                
            case .bodyweight:
                plannedExercise.targetSets = Int.random(in: 3...4)
                plannedExercise.targetReps = Int.random(in: 10...20)
                
            case .flexibility:
                plannedExercise.targetSets = 1
                plannedExercise.targetDuration = TimeInterval(Int.random(in: 5...10) * 60) // 5-10 minutes
            }
            
            plannedExercises.append(plannedExercise)
            modelContext.insert(plannedExercise)
        }
        
        plan.exercises = plannedExercises
        
        // Save immediately
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
    }
    
    private func setupForEditing() {
        guard let plan = existingPlan else { return }
        
        planName = plan.name
        planDate = plan.date
        planNotes = plan.notes ?? ""
    }
    
    private func updateWorkoutPlan() {
        guard let plan = existingPlan else { return }
        
        plan.name = planName
        plan.date = planDate
        plan.notes = planNotes.isEmpty ? nil : planNotes
        
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
        
        dismiss()
    }
    
    private func loadGeminiAPIKey() {
        geminiAPIKey = UserDefaults.standard.string(forKey: "GeminiAPIKey") ?? ""
    }
}

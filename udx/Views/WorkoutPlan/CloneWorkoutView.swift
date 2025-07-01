import SwiftUI
import SwiftData

struct CloneWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutPlan.date, order: .reverse) private var workoutPlans: [WorkoutPlan]
    
    @State private var selectedPlan: WorkoutPlan?
    @State private var targetDate = Date()
    @State private var newName = ""
    @State private var makeTemplate = false
    @State private var showTemplatesOnly = false
    
    var onWorkoutCreated: ((WorkoutPlan) -> Void)?
    
    var filteredPlans: [WorkoutPlan] {
        if showTemplatesOnly {
            return workoutPlans.filter { $0.isTemplate }
        } else {
            return workoutPlans.filter { !$0.isTemplate }
        }
    }
    
    var canCreate: Bool {
        selectedPlan != nil && !newName.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Clone From") {
                    Toggle("Show Templates Only", isOn: $showTemplatesOnly)
                    
                    if filteredPlans.isEmpty {
                        Text(showTemplatesOnly ? "No templates available" : "No previous workouts")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Workout", selection: $selectedPlan) {
                            Text("None").tag(nil as WorkoutPlan?)
                            ForEach(filteredPlans) { plan in
                                VStack(alignment: .leading) {
                                    Text(plan.name)
                                    Text(plan.formattedDate)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(plan as WorkoutPlan?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    if let plan = selectedPlan {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("\(plan.exerciseCount) exercises", systemImage: "dumbbell")
                                .font(.caption)
                            
                            Text(plan.muscleGroupNames)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let notes = plan.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("New Workout Details") {
                    TextField("Workout Name", text: $newName)
                        .onChange(of: selectedPlan) { _, plan in
                            if let plan = plan {
                                newName = plan.name
                            }
                        }
                    
                    DatePicker("Date", selection: $targetDate, displayedComponents: .date)
                    
                    Toggle("Save as Template", isOn: $makeTemplate)
                }
                
                if !filteredPlans.isEmpty && !showTemplatesOnly {
                    Section {
                        Button("Clone Yesterday's Workout") {
                            cloneYesterdayWorkout()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Clone Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        cloneWorkout()
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }
    
    private func cloneYesterdayWorkout() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayStart = Calendar.current.startOfDay(for: yesterday)
        let yesterdayEnd = Calendar.current.date(byAdding: .day, value: 1, to: yesterdayStart) ?? yesterday
        
        // Find workout from yesterday
        if let yesterdayPlan = workoutPlans.first(where: { plan in
            plan.date >= yesterdayStart && plan.date < yesterdayEnd && !plan.isTemplate
        }) {
            selectedPlan = yesterdayPlan
            newName = yesterdayPlan.name
            targetDate = Date()
            cloneWorkout()
        }
    }
    
    private func cloneWorkout() {
        guard let sourcePlan = selectedPlan else { return }
        
        // Create new workout plan
        let newPlan = WorkoutPlan(
            date: targetDate,
            name: newName,
            notes: sourcePlan.notes
        )
        newPlan.isTemplate = makeTemplate
        
        modelContext.insert(newPlan)
        
        // Clone exercises
        if let sourceExercises = sourcePlan.exercises {
            var clonedExercises: [PlannedExercise] = []
            
            for sourceExercise in sourceExercises.sorted(by: { $0.order < $1.order }) {
                let clonedExercise = PlannedExercise(
                    exercise: sourceExercise.exercise,
                    order: sourceExercise.order,
                    targetSets: sourceExercise.targetSets,
                    targetReps: sourceExercise.targetReps,
                    targetDuration: sourceExercise.targetDuration,
                    targetDistance: sourceExercise.targetDistance
                )
                
                clonedExercise.targetWeight = sourceExercise.targetWeight
                clonedExercise.distanceUnit = sourceExercise.distanceUnit
                clonedExercise.workoutPlan = newPlan
                
                modelContext.insert(clonedExercise)
                clonedExercises.append(clonedExercise)
            }
            
            newPlan.exercises = clonedExercises
        }
        
        // Clone target muscles
        if let sourceMuscles = sourcePlan.targetMuscles {
            newPlan.targetMuscles = sourceMuscles
        }
        
        // Save
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
        
        // Callback
        onWorkoutCreated?(newPlan)
        
        dismiss()
    }
}

import SwiftUI
import SwiftData

struct LogExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var plannedExercise: PlannedExercise
    
    @State private var currentSet = 1
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var isWarmup = false
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                exerciseInfoSection
                
                Form {
                    Section("Log Set \(currentSet)") {
                        Stepper("Reps: \(reps)", value: $reps, in: 1...30)
                        
                        HStack {
                            Text("Weight:")
                            Spacer()
                            TextField("Weight", value: $weight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("kg")
                        }
                        
                        Toggle("Warm-up Set", isOn: $isWarmup)
                        
                        TextField("Notes", text: $notes)
                    }
                    
                    Section {
                        Button("Log Set") {
                            logCurrentSet()
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(weight <= 0)
                    }
                    
                    if let logs = plannedExercise.logs, !logs.isEmpty {
                        Section("Completed Sets") {
                            ForEach(logs.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                                HStack {
                                    Text("Set \(set.setNumber)")
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Text("\(set.reps) reps × \(String(format: "%.1f", set.weight)) kg")
                                    
                                    if set.isWarmup {
                                        Text("(Warm-up)")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        updateExerciseStatus()
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }
    
    private var exerciseInfoSection: some View {
        VStack(spacing: 8) {
            Text(plannedExercise.exercise.name)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("\(plannedExercise.exercise.muscleGroup) • \(plannedExercise.exercise.minorMuscle)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let lastLog = plannedExercise.lastWorkout {
                Text("Last workout: \(lastLog.sets) sets × \(lastLog.reps) reps at \(String(format: "%.1f", lastLog.weight))kg")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Target: \(plannedExercise.targetSets) sets", systemImage: "list.bullet")
                Divider()
                Label("\(plannedExercise.targetReps) reps", systemImage: "repeat")
                Divider()
                if let targetWeight = plannedExercise.targetWeight {
                    Label("\(String(format: "%.1f", targetWeight))kg", systemImage: "scalemass")
                }
            }
            .font(.caption)
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func setupInitialValues() {
        // Set initial values based on target or previous sets
        if let logs = plannedExercise.logs, let lastSet = logs.max(by: { $0.setNumber < $1.setNumber }) {
            currentSet = lastSet.setNumber + 1
            reps = lastSet.reps
            weight = lastSet.weight
        } else {
            // Start with target values
            reps = plannedExercise.targetReps
            
            // Use suggested weight from progressive overload calculation
            weight = plannedExercise.suggestedWeight
        }
    }
    
    private func logCurrentSet() {
        // Create new set log
        let workoutSet = WorkoutSet(
            setNumber: currentSet,
            reps: reps,
            weight: weight,
            isWarmup: isWarmup,
            notes: notes.isEmpty ? nil : notes
        )
        
        workoutSet.plannedExercise = plannedExercise
        modelContext.insert(workoutSet)
        
        // Add to planned exercise
        if plannedExercise.logs == nil {
            plannedExercise.logs = [workoutSet]
        } else {
            plannedExercise.logs?.append(workoutSet)
        }
        
        // Add to exercise history (aggregated)
        createOrUpdateExerciseLog()
        
        // Move to next set
        currentSet += 1
        notes = ""
        isWarmup = false
        
        // Save
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
    }
    
    private func createOrUpdateExerciseLog() {
        // Create or update the exercise log for tracking history
        let today = Calendar.current.startOfDay(for: Date())
        
        // Find log for today if exists
        let existingLog = plannedExercise.exercise.workoutHistory?.first { log in
            Calendar.current.isDate(log.date, inSameDayAs: today)
        }
        
        if let log = existingLog {
            // Update existing log with new totals
            if let logs = plannedExercise.logs {
                // Count only non-warmup sets
                let workingSets = logs.filter { !$0.isWarmup }
                log.sets = workingSets.count
                
                // Average reps and weight
                if !workingSets.isEmpty {
                    log.reps = Int(workingSets.map { $0.reps }.reduce(0, +) / workingSets.count)
                    log.weight = workingSets.map { $0.weight }.reduce(0, +) / Double(workingSets.count)
                }
            }
        } else {
            // Create new log
            let newLog = ExerciseLog(
                date: today,
                sets: 1,
                reps: reps,
                weight: weight,
                notes: nil,
                exercise: plannedExercise.exercise
            )
            
            modelContext.insert(newLog)
            
            if plannedExercise.exercise.workoutHistory == nil {
                plannedExercise.exercise.workoutHistory = [newLog]
            } else {
                plannedExercise.exercise.workoutHistory?.append(newLog)
            }
        }
    }
    
    private func updateExerciseStatus() {
        // Mark exercise as completed if all sets are done
        if let logs = plannedExercise.logs, !logs.isEmpty {
            // Only count non-warmup sets
            let workingSets = logs.filter { !$0.isWarmup }
            
            if workingSets.count >= plannedExercise.targetSets {
                plannedExercise.isCompleted = true
            }
        }
        
        // Update parent workout plan completion status
        if let plan = plannedExercise.workoutPlan {
            if let exercises = plan.exercises, !exercises.isEmpty {
                let allCompleted = exercises.allSatisfy { $0.isCompleted }
                if allCompleted {
                    plan.isCompleted = true
                }
            }
        }
        
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
    }
}

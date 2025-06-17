import SwiftUI
import SwiftData

struct ExerciseLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let exercise: Exercise
    
    @State private var sets: [TempWorkoutSet] = []
    @State private var currentSetNumber = 1
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var notes = ""
    @State private var showingHistory = false
    
    // Temporary structure for sets before saving
    struct TempWorkoutSet: Identifiable {
        let id = UUID()
        let setNumber: Int
        let reps: Int
        let weight: Double
        let notes: String
    }
    
    var lastWorkout: ExerciseLog? {
        exercise.workoutHistory?.sorted(by: { $0.date > $1.date }).first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Exercise info
                    exerciseInfoSection
                    
                    // Add set form
                    addSetForm
                    
                    // Current sets
                    if !sets.isEmpty {
                        currentSetsSection
                    }
                    
                    // Save button
                    if !sets.isEmpty {
                        Button("Save Workout") {
                            saveWorkout()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Log \(exercise.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("History") {
                        showingHistory = true
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                ExerciseHistoryView(exercise: exercise)
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }
    
    private var exerciseInfoSection: some View {
        VStack(spacing: 8) {
            Text(exercise.name)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("\(exercise.muscleGroup) • \(exercise.minorMuscle)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let lastWorkout = lastWorkout {
                VStack(spacing: 4) {
                    Text("Last workout: \(lastWorkout.date, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(lastWorkout.sets) sets × \(lastWorkout.reps) reps @ \(String(format: "%.1f", lastWorkout.weight))kg")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var addSetForm: some View {
        VStack(spacing: 16) {
            Text("Add Set \(currentSetNumber)")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Stepper(value: $reps, in: 1...50) {
                        Text("\(reps)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Weight (kg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("0", value: $weight, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        
                        Stepper("", value: $weight, in: 0...500, step: 2.5)
                            .labelsHidden()
                    }
                }
            }
            
            TextField("Notes (optional)", text: $notes)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Add Set") {
                addSet()
            }
            .buttonStyle(.bordered)
            .disabled(weight <= 0)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var currentSetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Sets")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(sets) { set in
                HStack {
                    Text("Set \(set.setNumber)")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(set.reps) reps × \(String(format: "%.1f", set.weight)) kg")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .gray.opacity(0.2), radius: 2)
                .padding(.horizontal)
            }
        }
    }
    
    private func setupInitialValues() {
        // If there's previous workout data, use it as a starting point
        if let lastWorkout = lastWorkout {
            reps = lastWorkout.reps
            weight = lastWorkout.weight
        }
    }
    
    private func addSet() {
        let newSet = TempWorkoutSet(
            setNumber: currentSetNumber,
            reps: reps,
            weight: weight,
            notes: notes
        )
        
        sets.append(newSet)
        currentSetNumber += 1
        notes = ""
        
        // Keep same reps/weight for convenience
    }
    
    private func saveWorkout() {
        guard !sets.isEmpty else { return }
        
        // Calculate averages for the log
        let totalSets = sets.count
        let avgReps = sets.reduce(0) { $0 + $1.reps } / totalSets
        let avgWeight = sets.reduce(0.0) { $0 + $1.weight } / Double(totalSets)
        
        // Create exercise log
        let log = ExerciseLog(
            date: Date(),
            sets: totalSets,
            reps: avgReps,
            weight: avgWeight,
            notes: notes.isEmpty ? nil : notes,
            exercise: exercise
        )
        
        modelContext.insert(log)
        
        // Add to exercise history
        if exercise.workoutHistory == nil {
            exercise.workoutHistory = [log]
        } else {
            exercise.workoutHistory?.append(log)
        }
        
        // Save
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
        
        dismiss()
    }
}

// History view
struct ExerciseHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    
    var sortedHistory: [ExerciseLog] {
        exercise.workoutHistory?.sorted(by: { $0.date > $1.date }) ?? []
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedHistory) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.date, style: .date)
                            .font(.headline)
                        
                        HStack {
                            Text("\(log.sets) sets × \(log.reps) reps")
                            Spacer()
                            Text("\(String(format: "%.1f", log.weight)) kg")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        
                        if let notes = log.notes {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

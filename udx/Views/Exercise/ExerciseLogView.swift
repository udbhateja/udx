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
    @State private var duration: TimeInterval = 0
    @State private var distance = 0.0
    @State private var distanceUnit = "km"
    @State private var notes = ""
    @State private var showingHistory = false
    
    // For duration picker
    @State private var minutes = 0
    @State private var seconds = 0
    
    // Temporary structure for sets before saving
    struct TempWorkoutSet: Identifiable {
        let id = UUID()
        let setNumber: Int
        let reps: Int
        let weight: Double
        let duration: TimeInterval?
        let distance: Double?
        let distanceUnit: String
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
            
            HStack {
                Text(exercise.exerciseType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(backgroundForType(exercise.exerciseType))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
                Text("\(exercise.allMajorMuscleNames)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let lastWorkout = lastWorkout {
                VStack(spacing: 4) {
                    Text("Last workout: \(lastWorkout.date, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatLastWorkout(lastWorkout))
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
            
            switch exercise.exerciseType {
            case .weight:
                weightInputs
            case .cardio:
                cardioInputs
            case .bodyweight:
                bodyweightInputs
            case .flexibility:
                flexibilityInputs
            }
            
            TextField("Notes (optional)", text: $notes)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Add Set") {
                addSet()
            }
            .buttonStyle(.bordered)
            .disabled(!isValidInput)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var isValidInput: Bool {
        switch exercise.exerciseType {
        case .weight:
            return weight > 0
        case .cardio:
            let metric = exercise.cardioMetric
            if metric == .time {
                return duration > 0
            } else if metric == .distance {
                return distance > 0
            } else {
                return duration > 0 || distance > 0
            }
        case .bodyweight:
            return reps > 0
        case .flexibility:
            return duration > 0
        }
    }
    
    private var weightInputs: some View {
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
    }
    
    private var cardioInputs: some View {
        VStack(spacing: 12) {
            let metric = exercise.cardioMetric
            
            if metric == .time || metric == .both {
                VStack(alignment: .leading) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<120) { min in
                                Text("\(min)").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        
                        Text("min")
                        
                        Picker("Seconds", selection: $seconds) {
                            ForEach(0..<60) { sec in
                                Text("\(sec)").tag(sec)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        
                        Text("sec")
                    }
                }
                .onChange(of: minutes) { _, _ in updateDuration() }
                .onChange(of: seconds) { _, _ in updateDuration() }
            }
            
            if metric == .distance || metric == .both {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("0", value: $distance, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                    
                    Spacer()
                    
                    Picker("Unit", selection: $distanceUnit) {
                        Text("km").tag("km")
                        Text("miles").tag("miles")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }
        }
    }
    
    private var bodyweightInputs: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Reps")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Stepper(value: $reps, in: 1...100) {
                    Text("\(reps)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            if exercise.supportsWeight {
                VStack(alignment: .leading) {
                    Text("Added Weight (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("0", value: $weight, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        
                        Text("kg")
                    }
                }
            }
        }
    }
    
    private var flexibilityInputs: some View {
        VStack(alignment: .leading) {
            Text("Duration")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Picker("Minutes", selection: $minutes) {
                    ForEach(0..<30) { min in
                        Text("\(min)").tag(min)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
                
                Text("min")
                
                Picker("Seconds", selection: $seconds) {
                    ForEach(0..<60) { sec in
                        Text("\(sec)").tag(sec)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
                
                Text("sec")
            }
        }
        .onChange(of: minutes) { _, _ in updateDuration() }
        .onChange(of: seconds) { _, _ in updateDuration() }
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
                    
                    Text(formatSetDisplay(set))
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
            switch exercise.exerciseType {
            case .weight, .bodyweight:
                reps = lastWorkout.reps
                weight = lastWorkout.weight
            case .cardio:
                if let lastDuration = lastWorkout.duration {
                    duration = lastDuration
                    minutes = Int(lastDuration) / 60
                    seconds = Int(lastDuration) % 60
                }
                if let lastDistance = lastWorkout.distance {
                    distance = lastDistance
                    distanceUnit = lastWorkout.distanceUnit
                }
            case .flexibility:
                if let lastDuration = lastWorkout.duration {
                    duration = lastDuration
                    minutes = Int(lastDuration) / 60
                    seconds = Int(lastDuration) % 60
                }
            }
        }
    }
    
    private func updateDuration() {
        duration = TimeInterval(minutes * 60 + seconds)
    }
    
    private func addSet() {
        let newSet = TempWorkoutSet(
            setNumber: currentSetNumber,
            reps: exercise.exerciseType == .cardio || exercise.exerciseType == .flexibility ? 0 : reps,
            weight: weight,
            duration: exercise.exerciseType == .cardio || exercise.exerciseType == .flexibility ? duration : nil,
            distance: exercise.exerciseType == .cardio ? distance : nil,
            distanceUnit: distanceUnit,
            notes: notes
        )
        
        sets.append(newSet)
        currentSetNumber += 1
        notes = ""
    }
    
    private func saveWorkout() {
        guard !sets.isEmpty else { return }
        
        // Create exercise log based on exercise type
        let log: ExerciseLog
        
        switch exercise.exerciseType {
        case .weight, .bodyweight:
            let totalSets = sets.count
            let avgReps = sets.reduce(0) { $0 + $1.reps } / totalSets
            let avgWeight = sets.reduce(0.0) { $0 + $1.weight } / Double(totalSets)
            
            log = ExerciseLog(
                date: Date(),
                sets: totalSets,
                reps: avgReps,
                weight: avgWeight,
                notes: notes.isEmpty ? nil : notes,
                exercise: exercise
            )
            
        case .cardio:
            let totalDuration = sets.compactMap { $0.duration }.reduce(0, +)
            let totalDistance = sets.compactMap { $0.distance }.reduce(0, +)
            
            log = ExerciseLog(
                date: Date(),
                sets: sets.count,
                reps: 0,
                weight: 0,
                duration: totalDuration > 0 ? totalDuration : nil,
                distance: totalDistance > 0 ? totalDistance : nil,
                notes: notes.isEmpty ? nil : notes,
                exercise: exercise
            )
            log.distanceUnit = distanceUnit
            
        case .flexibility:
            let totalDuration = sets.compactMap { $0.duration }.reduce(0, +)
            
            log = ExerciseLog(
                date: Date(),
                sets: sets.count,
                reps: 0,
                weight: 0,
                duration: totalDuration,
                notes: notes.isEmpty ? nil : notes,
                exercise: exercise
            )
        }
        
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
    
    private func formatSetDisplay(_ set: TempWorkoutSet) -> String {
        switch exercise.exerciseType {
        case .weight:
            return "\(set.reps) reps × \(String(format: "%.1f", set.weight)) kg"
        case .cardio:
            var parts: [String] = []
            if let duration = set.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                parts.append(String(format: "%d:%02d", minutes, seconds))
            }
            if let distance = set.distance {
                parts.append("\(String(format: "%.2f", distance)) \(set.distanceUnit)")
            }
            return parts.joined(separator: " • ")
        case .bodyweight:
            if set.weight > 0 {
                return "\(set.reps) reps (+\(String(format: "%.1f", set.weight)) kg)"
            } else {
                return "\(set.reps) reps"
            }
        case .flexibility:
            if let duration = set.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
            return "No duration"
        }
    }
    
    private func formatLastWorkout(_ log: ExerciseLog) -> String {
        switch exercise.exerciseType {
        case .weight:
            return "\(log.sets) sets × \(log.reps) reps @ \(String(format: "%.1f", log.weight))kg"
        case .cardio:
            var parts: [String] = []
            if let duration = log.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                parts.append(String(format: "%d:%02d", minutes, seconds))
            }
            if let distance = log.distance {
                parts.append("\(String(format: "%.2f", distance)) \(log.distanceUnit)")
            }
            return parts.joined(separator: " • ")
        case .bodyweight:
            if log.weight > 0 {
                return "\(log.sets) sets × \(log.reps) reps (+\(String(format: "%.1f", log.weight))kg)"
            } else {
                return "\(log.sets) sets × \(log.reps) reps"
            }
        case .flexibility:
            if let duration = log.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
            return "Completed"
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
                        
                        Text(formatHistoryLog(log))
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
    
    private func formatHistoryLog(_ log: ExerciseLog) -> String {
        switch exercise.exerciseType {
        case .weight:
            return "\(log.sets) sets × \(log.reps) reps @ \(String(format: "%.1f", log.weight)) kg"
        case .cardio:
            var parts: [String] = []
            if log.sets > 1 {
                parts.append("\(log.sets) sets")
            }
            if let duration = log.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                parts.append(String(format: "%d:%02d", minutes, seconds))
            }
            if let distance = log.distance {
                parts.append("\(String(format: "%.2f", distance)) \(log.distanceUnit)")
            }
            return parts.joined(separator: " • ")
        case .bodyweight:
            if log.weight > 0 {
                return "\(log.sets) sets × \(log.reps) reps (+\(String(format: "%.1f", log.weight)) kg)"
            } else {
                return "\(log.sets) sets × \(log.reps) reps"
            }
        case .flexibility:
            if let duration = log.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
            return "Completed"
        }
    }
}

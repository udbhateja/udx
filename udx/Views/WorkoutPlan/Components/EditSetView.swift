import SwiftUI
import SwiftData

struct EditSetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var workoutSet: WorkoutSet
    let plannedExercise: PlannedExercise
    let onSave: () -> Void
    
    @State private var reps: Int
    @State private var weight: Double
    @State private var duration: TimeInterval
    @State private var distance: Double
    @State private var distanceUnit: String
    @State private var isWarmup: Bool
    @State private var notes: String
    
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    
    var exerciseType: ExerciseType {
        plannedExercise.exercise.exerciseType
    }
    
    init(workoutSet: WorkoutSet, plannedExercise: PlannedExercise, onSave: @escaping () -> Void) {
        self.workoutSet = workoutSet
        self.plannedExercise = plannedExercise
        self.onSave = onSave
        
        _reps = State(initialValue: workoutSet.reps)
        _weight = State(initialValue: workoutSet.weight)
        _duration = State(initialValue: workoutSet.duration ?? 0)
        _distance = State(initialValue: workoutSet.distance ?? 0)
        _distanceUnit = State(initialValue: workoutSet.distanceUnit)
        _isWarmup = State(initialValue: workoutSet.isWarmup)
        _notes = State(initialValue: workoutSet.notes ?? "")
        
        let totalSeconds = Int(workoutSet.duration ?? 0)
        _minutes = State(initialValue: totalSeconds / 60)
        _seconds = State(initialValue: totalSeconds % 60)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Edit Set \(workoutSet.setNumber)") {
                    switch exerciseType {
                    case .weight:
                        weightExerciseInputs
                    case .cardio:
                        cardioExerciseInputs
                    case .bodyweight:
                        bodyweightExerciseInputs
                    case .flexibility:
                        flexibilityExerciseInputs
                    }
                    
                    if exerciseType != .flexibility {
                        Toggle("Warm-up Set", isOn: $isWarmup)
                    }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValidInput)
                }
            }
        }
    }
    
    private var isValidInput: Bool {
        switch exerciseType {
        case .weight:
            return weight > 0 || isWarmup
        case .cardio:
            let metric = plannedExercise.exercise.cardioMetric
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
    
    private var weightExerciseInputs: some View {
        Group {
            Stepper("Reps: \(reps)", value: $reps, in: 1...30)
            
            HStack {
                Text("Weight:")
                Spacer()
                TextField("Weight", value: $weight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("kg")
            }
        }
    }
    
    private var cardioExerciseInputs: some View {
        Group {
            let metric = plannedExercise.exercise.cardioMetric
            
            if metric == .time || metric == .both {
                VStack(alignment: .leading) {
                    Text("Duration")
                    HStack {
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<60) { min in
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
                    Text("Distance:")
                    Spacer()
                    TextField("Distance", value: $distance, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    
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
    
    private var bodyweightExerciseInputs: some View {
        Group {
            Stepper("Reps: \(reps)", value: $reps, in: 1...100)
            
            if plannedExercise.exercise.supportsWeight {
                HStack {
                    Text("Added Weight (optional):")
                    Spacer()
                    TextField("Weight", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("kg")
                }
            }
        }
    }
    
    private var flexibilityExerciseInputs: some View {
        VStack(alignment: .leading) {
            Text("Duration")
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
    
    private func updateDuration() {
        duration = TimeInterval(minutes * 60 + seconds)
    }
    
    private func saveChanges() {
        // Update the workout set
        workoutSet.reps = reps
        workoutSet.weight = weight
        workoutSet.duration = exerciseType == .cardio || exerciseType == .flexibility ? duration : nil
        workoutSet.distance = exerciseType == .cardio ? distance : nil
        workoutSet.distanceUnit = distanceUnit
        workoutSet.isWarmup = isWarmup
        workoutSet.notes = notes.isEmpty ? nil : notes
        
        // Update exercise history
        updateExerciseHistory()
        
        // Save changes
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
        
        onSave()
        dismiss()
    }
    
    private func updateExerciseHistory() {
        // Update the aggregated exercise log for today
        let today = Calendar.current.startOfDay(for: Date())
        
        // Find log for today
        guard let existingLog = plannedExercise.exercise.workoutHistory?.first(where: { log in
            Calendar.current.isDate(log.date, inSameDayAs: today)
        }), let logs = plannedExercise.logs else { return }
        
        // Count only non-warmup sets
        let workingSets = logs.filter { !$0.isWarmup }
        
        guard !workingSets.isEmpty else { return }
        
        // Update with new totals
        existingLog.sets = workingSets.count
        
        // Average values based on exercise type
        switch exerciseType {
        case .weight, .bodyweight:
            existingLog.reps = Int(workingSets.map { $0.reps }.reduce(0, +) / workingSets.count)
            existingLog.weight = workingSets.map { $0.weight }.reduce(0, +) / Double(workingSets.count)
        case .cardio:
            if let totalDuration = workingSets.compactMap({ $0.duration }).reduce(0, +) as TimeInterval? {
                existingLog.duration = totalDuration
            }
            if let totalDistance = workingSets.compactMap({ $0.distance }).reduce(0, +) as Double? {
                existingLog.distance = totalDistance
            }
            existingLog.distanceUnit = distanceUnit
        case .flexibility:
            if let totalDuration = workingSets.compactMap({ $0.duration }).reduce(0, +) as TimeInterval? {
                existingLog.duration = totalDuration
            }
        }
    }
}

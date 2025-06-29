import SwiftUI
import SwiftData

struct EditPlannedExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var plannedExercise: PlannedExercise
    
    @State private var targetSets: Int
    @State private var targetReps: Int
    @State private var targetWeight: Double
    @State private var targetDuration: TimeInterval
    @State private var targetDistance: Double
    @State private var distanceUnit: String
    
    // For duration picker
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    
    var exerciseType: ExerciseType {
        plannedExercise.exercise.exerciseType
    }
    
    init(plannedExercise: PlannedExercise) {
        self.plannedExercise = plannedExercise
        _targetSets = State(initialValue: plannedExercise.targetSets)
        _targetReps = State(initialValue: plannedExercise.targetReps)
        _targetWeight = State(initialValue: plannedExercise.targetWeight ?? 0)
        _targetDuration = State(initialValue: plannedExercise.targetDuration ?? 0)
        _targetDistance = State(initialValue: plannedExercise.targetDistance ?? 0)
        _distanceUnit = State(initialValue: plannedExercise.distanceUnit)
        
        // Initialize time pickers
        if let duration = plannedExercise.targetDuration {
            _minutes = State(initialValue: Int(duration) / 60)
            _seconds = State(initialValue: Int(duration) % 60)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    HStack {
                        Text("Exercise")
                        Spacer()
                        Text(plannedExercise.exercise.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(exerciseType.rawValue)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Muscle Group")
                        Spacer()
                        Text(plannedExercise.exercise.allMajorMuscleNames)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Target Parameters") {
                    switch exerciseType {
                    case .weight:
                        weightTargetInputs
                    case .cardio:
                        cardioTargetInputs
                    case .bodyweight:
                        bodyweightTargetInputs
                    case .flexibility:
                        flexibilityTargetInputs
                    }
                }
                
                if let lastWorkout = plannedExercise.lastWorkout {
                    Section("Previous Performance") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Date:")
                                Spacer()
                                Text(lastWorkout.date, style: .date)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Performance:")
                                Spacer()
                                Text(formatLastWorkout(lastWorkout))
                                    .foregroundColor(.secondary)
                            }
                            
                            if exerciseType == .weight && targetSets == 2 {
                                Text("Tip: 2 sets can be effective for maintenance or when time is limited")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .italic()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Exercise")
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
                }
            }
        }
    }
    
    private var weightTargetInputs: some View {
        Group {
            Stepper("Sets: \(targetSets)", value: $targetSets, in: 1...10)
            
            Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...30)
            
            HStack {
                Text("Target Weight")
                Spacer()
                TextField("Weight", value: $targetWeight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("kg")
            }
        }
    }
    
    private var cardioTargetInputs: some View {
        Group {
            let metric = plannedExercise.exercise.cardioMetric
            
            if metric == .time || metric == .both {
                VStack(alignment: .leading) {
                    Text("Target Duration")
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
                    Text("Target Distance")
                    Spacer()
                    TextField("Distance", value: $targetDistance, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    
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
    
    private var bodyweightTargetInputs: some View {
        Group {
            Stepper("Sets: \(targetSets)", value: $targetSets, in: 1...10)
            
            Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...50)
            
            if plannedExercise.exercise.supportsWeight {
                HStack {
                    Text("Target Added Weight")
                    Spacer()
                    TextField("Weight", value: $targetWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kg")
                }
            }
        }
    }
    
    private var flexibilityTargetInputs: some View {
        VStack(alignment: .leading) {
            Text("Target Duration")
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
        targetDuration = TimeInterval(minutes * 60 + seconds)
    }
    
    private func saveChanges() {
        switch exerciseType {
        case .weight:
            plannedExercise.targetSets = targetSets
            plannedExercise.targetReps = targetReps
            plannedExercise.targetWeight = targetWeight > 0 ? targetWeight : nil
            
        case .cardio:
            plannedExercise.targetSets = 1
            if plannedExercise.exercise.cardioMetric == .time || plannedExercise.exercise.cardioMetric == .both {
                plannedExercise.targetDuration = targetDuration
            }
            if plannedExercise.exercise.cardioMetric == .distance || plannedExercise.exercise.cardioMetric == .both {
                plannedExercise.targetDistance = targetDistance > 0 ? targetDistance : nil
                plannedExercise.distanceUnit = distanceUnit
            }
            
        case .bodyweight:
            plannedExercise.targetSets = targetSets
            plannedExercise.targetReps = targetReps
            if plannedExercise.exercise.supportsWeight {
                plannedExercise.targetWeight = targetWeight > 0 ? targetWeight : nil
            }
            
        case .flexibility:
            plannedExercise.targetSets = 1
            plannedExercise.targetDuration = targetDuration
        }
        
        // Save context
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
        
        dismiss()
    }
    
    private func formatLastWorkout(_ log: ExerciseLog) -> String {
        switch exerciseType {
        case .weight:
            return "\(log.sets) × \(log.reps) @ \(String(format: "%.1f", log.weight))kg"
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
                return "\(log.sets) × \(log.reps) (+\(String(format: "%.1f", log.weight))kg)"
            } else {
                return "\(log.sets) × \(log.reps)"
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

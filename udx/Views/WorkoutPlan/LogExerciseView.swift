import SwiftUI
import SwiftData

struct LogExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var plannedExercise: PlannedExercise
    
    @State private var currentSet = 1
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var duration: TimeInterval = 0
    @State private var distance = 0.0
    @State private var distanceUnit = "km"
    @State private var isWarmup = false
    @State private var notes = ""
    
    // For duration picker
    @State private var minutes = 0
    @State private var seconds = 0
    
    var exerciseType: ExerciseType {
        plannedExercise.exercise.exerciseType
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Add a simple test to ensure view loads
                if plannedExercise.exercise.name.isEmpty {
                    Text("Error: Exercise data not loaded")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    exerciseInfoSection
                }
                
                Form {
                    Section("Log Set \(currentSet)") {
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
                        
                        TextField("Notes", text: $notes)
                    }
                    
                    Section {
                        Button("Log Set") {
                            logCurrentSet()
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(!isValidInput)
                    }
                    
                    if let logs = plannedExercise.logs, !logs.isEmpty {
                        Section("Completed Sets") {
                            ForEach(logs.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                                HStack {
                                    Text("Set \(set.setNumber)")
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Text(formatSetDisplay(set))
                                    
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
    
    private var exerciseInfoSection: some View {
        VStack(spacing: 8) {
            Text(plannedExercise.exercise.name)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                Text(plannedExercise.exercise.allMajorMuscleNames)
                if !plannedExercise.exercise.allMinorMuscleNames.isEmpty {
                    Text("•")
                    Text(plannedExercise.exercise.allMinorMuscleNames)
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            if let lastLog = plannedExercise.lastWorkout {
                Text(formatLastWorkout(lastLog))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                switch exerciseType {
                case .weight:
                    Label("Target: \(plannedExercise.targetSets) sets", systemImage: "list.bullet")
                    Divider()
                    Label("\(plannedExercise.targetReps) reps", systemImage: "repeat")
                    if plannedExercise.lastWorkout != nil {
                        Divider()
                        Label("\(String(format: "%.1f", plannedExercise.suggestedWeight))kg", systemImage: "scalemass")
                    }
                case .cardio:
                    if let targetDuration = plannedExercise.targetDuration {
                        Label("Target: \(formatDuration(targetDuration))", systemImage: "timer")
                    }
                    if let targetDistance = plannedExercise.targetDistance {
                        Divider()
                        Label("\(String(format: "%.1f", targetDistance)) \(plannedExercise.distanceUnit)", systemImage: "figure.run")
                    }
                case .bodyweight:
                    Label("Target: \(plannedExercise.targetSets) sets", systemImage: "list.bullet")
                    Divider()
                    Label("\(plannedExercise.targetReps) reps", systemImage: "repeat")
                case .flexibility:
                    if let targetDuration = plannedExercise.targetDuration {
                        Label("Target: \(formatDuration(targetDuration))", systemImage: "timer")
                    }
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
            
            if let lastDuration = lastSet.duration {
                duration = lastDuration
                minutes = Int(lastDuration) / 60
                seconds = Int(lastDuration) % 60
            }
            
            if let lastDistance = lastSet.distance {
                distance = lastDistance
                distanceUnit = lastSet.distanceUnit
            }
        } else {
            // Start with target values
            switch exerciseType {
            case .weight, .bodyweight:
                reps = plannedExercise.targetReps
                if exerciseType == .weight && plannedExercise.lastWorkout != nil {
                    weight = plannedExercise.suggestedWeight
                }
            case .cardio:
                if let targetDuration = plannedExercise.targetDuration {
                    duration = targetDuration
                    minutes = Int(targetDuration) / 60
                    seconds = Int(targetDuration) % 60
                }
                if let targetDistance = plannedExercise.targetDistance {
                    distance = targetDistance
                    distanceUnit = plannedExercise.distanceUnit
                }
            case .flexibility:
                if let targetDuration = plannedExercise.targetDuration {
                    duration = targetDuration
                    minutes = Int(targetDuration) / 60
                    seconds = Int(targetDuration) % 60
                }
            }
        }
    }
    
    private func updateDuration() {
        duration = TimeInterval(minutes * 60 + seconds)
    }
    
    private func logCurrentSet() {
        // Create new set log
        let workoutSet = WorkoutSet(
            setNumber: currentSet,
            reps: exerciseType == .cardio || exerciseType == .flexibility ? 0 : reps,
            weight: weight,
            duration: exerciseType == .cardio || exerciseType == .flexibility ? duration : nil,
            distance: exerciseType == .cardio ? distance : nil,
            isWarmup: isWarmup,
            notes: notes.isEmpty ? nil : notes
        )
        
        if exerciseType == .cardio && distance > 0 {
            workoutSet.distanceUnit = distanceUnit
        }
        
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
                
                // Average values based on exercise type
                if !workingSets.isEmpty {
                    switch exerciseType {
                    case .weight, .bodyweight:
                        log.reps = Int(workingSets.map { $0.reps }.reduce(0, +) / workingSets.count)
                        log.weight = workingSets.map { $0.weight }.reduce(0, +) / Double(workingSets.count)
                    case .cardio:
                        if let totalDuration = workingSets.compactMap({ $0.duration }).reduce(0, +) as TimeInterval? {
                            log.duration = totalDuration
                        }
                        if let totalDistance = workingSets.compactMap({ $0.distance }).reduce(0, +) as Double? {
                            log.distance = totalDistance
                        }
                        log.distanceUnit = distanceUnit
                    case .flexibility:
                        if let totalDuration = workingSets.compactMap({ $0.duration }).reduce(0, +) as TimeInterval? {
                            log.duration = totalDuration
                        }
                    }
                }
            }
        } else {
            // Create new log
            let newLog = ExerciseLog(
                date: today,
                sets: 1,
                reps: exerciseType == .cardio || exerciseType == .flexibility ? 0 : reps,
                weight: weight,
                duration: exerciseType == .cardio || exerciseType == .flexibility ? duration : nil,
                distance: exerciseType == .cardio ? distance : nil,
                notes: nil,
                exercise: plannedExercise.exercise
            )
            
            if exerciseType == .cardio && distance > 0 {
                newLog.distanceUnit = distanceUnit
            }
            
            modelContext.insert(newLog)
            
            if plannedExercise.exercise.workoutHistory == nil {
                plannedExercise.exercise.workoutHistory = [newLog]
            } else {
                plannedExercise.exercise.workoutHistory?.append(newLog)
            }
        }
    }
    
    private func updateExerciseStatus() {
        // Mark exercise as completed if target sets are reached
        if let logs = plannedExercise.logs, !logs.isEmpty {
            // Only count non-warmup sets
            let workingSets = logs.filter { !$0.isWarmup }
            
            // Complete when we've done at least the target number of sets
            // This allows flexibility for 2-set workouts
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
    
    private func formatSetDisplay(_ set: WorkoutSet) -> String {
        switch exerciseType {
        case .weight:
            return "\(set.reps) reps × \(String(format: "%.1f", set.weight)) kg"
        case .cardio:
            var parts: [String] = []
            if let duration = set.duration {
                parts.append(formatDuration(duration))
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
                return formatDuration(duration)
            }
            return "No duration"
        }
    }
    
    private func formatLastWorkout(_ log: ExerciseLog) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        let dateStr = formatter.string(from: log.date)
        
        switch exerciseType {
        case .weight:
            return "Last: \(log.sets) sets × \(log.reps) reps at \(String(format: "%.1f", log.weight))kg on \(dateStr)"
        case .cardio:
            var parts: [String] = ["Last:"]
            if let duration = log.duration {
                parts.append(formatDuration(duration))
            }
            if let distance = log.distance {
                parts.append("\(String(format: "%.2f", distance)) \(log.distanceUnit)")
            }
            parts.append("on \(dateStr)")
            return parts.joined(separator: " ")
        case .bodyweight:
            if log.weight > 0 {
                return "Last: \(log.sets) sets × \(log.reps) reps (+\(String(format: "%.1f", log.weight))kg) on \(dateStr)"
            } else {
                return "Last: \(log.sets) sets × \(log.reps) reps on \(dateStr)"
            }
        case .flexibility:
            if let duration = log.duration {
                return "Last: \(formatDuration(duration)) on \(dateStr)"
            }
            return "Last workout on \(dateStr)"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

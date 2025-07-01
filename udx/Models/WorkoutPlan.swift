import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var date: Date
    var name: String
    var notes: String?
    var isCompleted: Bool = false
    var isTemplate: Bool = false
    
    @Relationship var targetMuscles: [MajorMuscle]?
    @Relationship var exercises: [PlannedExercise]?
    
    init(date: Date = Date(), name: String, notes: String? = nil) {
        self.date = date
        self.name = name
        self.notes = notes
    }
    
    // Helper properties
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var muscleGroupNames: String {
        // Derive muscle groups from exercises instead of target muscles
        guard let exercises = exercises, !exercises.isEmpty else { return "No exercises" }
        
        var muscleGroups = Set<String>()
        for plannedExercise in exercises {
            if let majorMuscles = plannedExercise.exercise.majorMuscles {
                for muscle in majorMuscles {
                    muscleGroups.insert(muscle.name)
                }
            } else {
                // Fallback to legacy string property
                muscleGroups.insert(plannedExercise.exercise.muscleGroup)
            }
        }
        
        return muscleGroups.isEmpty ? "No target muscles" : muscleGroups.sorted().joined(separator: ", ")
    }
    
    var exerciseCount: Int {
        return exercises?.count ?? 0
    }
    
    var completedExercises: Int {
        return exercises?.filter { $0.isCompleted }.count ?? 0
    }
}

@Model
final class PlannedExercise {
    // Reference to the actual exercise
    @Relationship var exercise: Exercise
    var order: Int
    var isCompleted: Bool = false
    var targetSets: Int
    var targetReps: Int
    var targetWeight: Double?
    
    // Additional targets for different exercise types
    var targetDuration: TimeInterval? // For cardio/flexibility exercises (in seconds)
    var targetDistance: Double? // For cardio exercises
    var distanceUnit: String = "km" // km or miles
    
    // Workout logs for this planned exercise
    @Relationship var logs: [WorkoutSet]?
    
    // Relationship to parent workout
    @Relationship(inverse: \WorkoutPlan.exercises) var workoutPlan: WorkoutPlan?
    
    init(exercise: Exercise, order: Int = 0, targetSets: Int = 3, targetReps: Int = 10, targetDuration: TimeInterval? = nil, targetDistance: Double? = nil) {
        self.exercise = exercise
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetDuration = targetDuration
        self.targetDistance = targetDistance
        
        // Set default targets based on exercise type
        switch exercise.exerciseType {
        case .cardio:
            if targetDuration == nil {
                self.targetDuration = 1800 // Default 30 minutes
            }
        case .flexibility:
            if targetDuration == nil {
                self.targetDuration = 300 // Default 5 minutes
            }
        default:
            break
        }
    }
    
    // Last workout data for this exercise
    var lastWorkout: ExerciseLog? {
        return exercise.workoutHistory?.sorted(by: { $0.date > $1.date }).first
    }
    
    // Completion status
    var completionStatus: String {
        if isCompleted {
            return "Completed"
        } else if let logs = logs, !logs.isEmpty {
            return "\(logs.count)/\(targetSets) sets"
        } else {
            return "Not started"
        }
    }
    
    // Helper for progressive overload
    var suggestedWeight: Double {
        let recommendation = ProgressiveOverloadCalculator.calculateProgressiveOverload(
            for: exercise,
            currentLog: lastWorkout,
            targetSets: targetSets,
            targetReps: targetReps
        )
        return recommendation.suggestedWeight
    }
    
    // Get full progressive overload recommendation
    var progressiveOverloadRecommendation: ProgressiveOverloadCalculator.OverloadRecommendation {
        return ProgressiveOverloadCalculator.calculateProgressiveOverload(
            for: exercise,
            currentLog: lastWorkout,
            targetSets: targetSets,
            targetReps: targetReps
        )
    }
}

@Model
final class WorkoutSet {
    var setNumber: Int
    var reps: Int
    var weight: Double
    var date: Date = Date()
    var notes: String?
    var isWarmup: Bool = false
    
    // Additional metrics for different exercise types
    var duration: TimeInterval? // For cardio/flexibility exercises (in seconds)
    var distance: Double? // For cardio exercises (in km/miles)
    var distanceUnit: String = "km" // km or miles
    
    // Relationship to planned exercise
    @Relationship(inverse: \PlannedExercise.logs) var plannedExercise: PlannedExercise?
    
    init(setNumber: Int, reps: Int = 0, weight: Double = 0, duration: TimeInterval? = nil, distance: Double? = nil, isWarmup: Bool = false, notes: String? = nil) {
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.distance = distance
        self.isWarmup = isWarmup
        self.notes = notes
    }
    
    // Helper computed properties
    var formattedDuration: String {
        guard let duration = duration else { return "" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedDistance: String {
        guard let distance = distance else { return "" }
        return String(format: "%.2f %@", distance, distanceUnit)
    }
}

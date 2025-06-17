import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var date: Date
    var name: String
    var notes: String?
    var isCompleted: Bool = false
    
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
        guard let muscles = targetMuscles, !muscles.isEmpty else { return "No target muscles" }
        return muscles.map { $0.name }.joined(separator: ", ")
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
    
    // Workout logs for this planned exercise
    @Relationship var logs: [WorkoutSet]?
    
    // Relationship to parent workout
    @Relationship(inverse: \WorkoutPlan.exercises) var workoutPlan: WorkoutPlan?
    
    init(exercise: Exercise, order: Int = 0, targetSets: Int = 3, targetReps: Int = 10) {
        self.exercise = exercise
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
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
        guard let lastLog = lastWorkout else {
            return 0 // Return 0 if no previous workout data
        }
        
        // Simple progressive overload: 5% increase if completed all reps last time
        if lastLog.reps >= targetReps {
            return lastLog.weight * 1.05
        } else {
            return lastLog.weight
        }
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
    
    // Relationship to planned exercise
    @Relationship(inverse: \PlannedExercise.logs) var plannedExercise: PlannedExercise?
    
    init(setNumber: Int, reps: Int, weight: Double, isWarmup: Bool = false, notes: String? = nil) {
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.isWarmup = isWarmup
        self.notes = notes
    }
}

import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var date: Date
    var name: String
    var notes: String?
    var targetMuscles: [String]  // Store muscle group names
    @Relationship(deleteRule: .cascade) var exercises: [PlanExercise] = []
    
    init(date: Date, name: String, notes: String? = nil, targetMuscles: [String]) {
        self.date = date
        self.name = name
        self.notes = notes
        self.targetMuscles = targetMuscles
    }
}

@Model
final class PlanExercise {
    @Relationship(inverse: \WorkoutPlan.exercises) var plan: WorkoutPlan?
    var exerciseId: PersistentIdentifier
    var exerciseName: String
    var order: Int
    @Relationship(deleteRule: .cascade) var logs: [WorkoutLog] = []
    
    init(exerciseId: PersistentIdentifier, exerciseName: String, order: Int) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.order = order
    }
}

import Foundation
import SwiftData

@Model
final class WorkoutLog {
    var date: Date
    var sets: Int
    var reps: Int
    var weight: Double
    var notes: String?
    @Relationship(inverse: \PlannedExercise.logs) var planExercise: PlannedExercise?
    
    init(date: Date, sets: Int, reps: Int, weight: Double, notes: String? = nil) {
        self.date = date
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.notes = notes
    }
}

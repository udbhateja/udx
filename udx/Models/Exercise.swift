import Foundation
import SwiftData
import SwiftUI

@Model
final class Exercise {
    var name: String
    var details: String
    var muscleGroup: String // Primary muscle group (for backward compatibility)
    var minorMuscle: String // Primary minor muscle (for backward compatibility)
    var imageData: Data? // Optional image data
    var videoURL: URL?   // Optional YouTube video link
    
    // Multiple muscle relationships
    @Relationship(inverse: \MajorMuscle.exercises) var majorMuscles: [MajorMuscle]?
    @Relationship(inverse: \MinorMuscle.exercises) var minorMuscles: [MinorMuscle]?
    
    // For efficient queries - primary relationships
    var majorMuscleRef: MajorMuscle? {
        get { majorMuscles?.first }
        set {
            if let newValue {
                if majorMuscles == nil {
                    majorMuscles = [newValue]
                } else if !majorMuscles!.contains(where: { $0.id == newValue.id }) {
                    majorMuscles!.append(newValue)
                }
            }
        }
    }
    
    var minorMuscleRef: MinorMuscle? {
        get { minorMuscles?.first }
        set {
            if let newValue {
                if minorMuscles == nil {
                    minorMuscles = [newValue]
                } else if !minorMuscles!.contains(where: { $0.id == newValue.id }) {
                    minorMuscles!.append(newValue)
                }
            }
        }
    }
    
    // History of previous workouts using this exercise
    @Relationship var workoutHistory: [ExerciseLog]?
    
    init(name: String, details: String = "", muscleGroup: String, minorMuscle: String = "") {
        self.name = name
        self.details = details
        self.muscleGroup = muscleGroup
        self.minorMuscle = minorMuscle
    }
    
    // Helper to get all muscle names as a string
    var allMajorMuscleNames: String {
        guard let muscles = majorMuscles, !muscles.isEmpty else { return muscleGroup }
        return muscles.map { $0.name }.joined(separator: ", ")
    }
    
    var allMinorMuscleNames: String {
        guard let muscles = minorMuscles, !muscles.isEmpty else { return minorMuscle }
        return muscles.map { $0.name }.joined(separator: ", ")
    }
}

@Model
final class ExerciseLog {
    var date: Date
    var sets: Int
    var reps: Int
    var weight: Double
    var notes: String?
    
    @Relationship var exercise: Exercise?
    
    init(date: Date = Date(), sets: Int = 0, reps: Int = 0, weight: Double = 0, notes: String? = nil, exercise: Exercise? = nil) {
        self.date = date
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.notes = notes
        self.exercise = exercise
    }
}

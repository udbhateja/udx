import Foundation
import SwiftData
import SwiftUI

enum ExerciseType: String, Codable, CaseIterable {
    case weight = "Weight"
    case cardio = "Cardio"
    case bodyweight = "Bodyweight"
    case flexibility = "Flexibility"
}

enum CardioMetric: String, Codable, CaseIterable {
    case time = "Time"
    case distance = "Distance"
    case both = "Time & Distance"
}

@Model
final class Exercise {
    var name: String
    var details: String
    var muscleGroup: String // Primary muscle group (for backward compatibility)
    var minorMuscle: String // Primary minor muscle (for backward compatibility)
    var imageData: Data? // Optional image data
    var videoURL: URL?   // Optional YouTube video link
    
    // Exercise type properties
    var exerciseTypeRaw: String = ExerciseType.weight.rawValue
    var cardioMetricRaw: String = CardioMetric.time.rawValue
    var supportsWeight: Bool = true // For bodyweight exercises that can optionally add weight
    
    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRaw) ?? .weight }
        set { exerciseTypeRaw = newValue.rawValue }
    }
    
    var cardioMetric: CardioMetric {
        get { CardioMetric(rawValue: cardioMetricRaw) ?? .time }
        set { cardioMetricRaw = newValue.rawValue }
    }
    
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
    
    init(name: String, details: String = "", muscleGroup: String, minorMuscle: String = "", exerciseType: ExerciseType = .weight) {
        self.name = name
        self.details = details
        self.muscleGroup = muscleGroup
        self.minorMuscle = minorMuscle
        self.exerciseTypeRaw = exerciseType.rawValue
        
        // Set default properties based on exercise type
        switch exerciseType {
        case .weight:
            self.supportsWeight = true
        case .cardio:
            self.supportsWeight = false
        case .bodyweight:
            self.supportsWeight = true // Can optionally add weight
        case .flexibility:
            self.supportsWeight = false
        }
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
    
    // Additional metrics for different exercise types
    var duration: TimeInterval? // For cardio/flexibility exercises (in seconds)
    var distance: Double? // For cardio exercises (in km/miles)
    var distanceUnit: String = "km" // km or miles
    
    @Relationship var exercise: Exercise?
    
    init(date: Date = Date(), sets: Int = 0, reps: Int = 0, weight: Double = 0, duration: TimeInterval? = nil, distance: Double? = nil, notes: String? = nil, exercise: Exercise? = nil) {
        self.date = date
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.distance = distance
        self.notes = notes
        self.exercise = exercise
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

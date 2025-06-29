import Foundation

struct ProgressiveOverloadCalculator {
    
    enum OverloadStrategy {
        case increaseWeight
        case increaseReps
        case increaseSets
        case maintainCurrent
    }
    
    struct OverloadRecommendation {
        let strategy: OverloadStrategy
        let suggestedWeight: Double
        let suggestedReps: Int
        let suggestedSets: Int
        let explanation: String
    }
    
    static func calculateProgressiveOverload(
        for exercise: Exercise,
        currentLog: ExerciseLog?,
        targetSets: Int,
        targetReps: Int
    ) -> OverloadRecommendation {
        
        guard let currentLog = currentLog else {
            // No previous workout, start conservative
            return OverloadRecommendation(
                strategy: .maintainCurrent,
                suggestedWeight: 0,
                suggestedReps: targetReps,
                suggestedSets: targetSets,
                explanation: "First time performing this exercise. Start with bodyweight or light weight."
            )
        }
        
        switch exercise.exerciseType {
        case .weight:
            return calculateWeightProgression(currentLog: currentLog, targetSets: targetSets, targetReps: targetReps)
            
        case .cardio:
            return calculateCardioProgression(currentLog: currentLog, exercise: exercise)
            
        case .bodyweight:
            return calculateBodyweightProgression(currentLog: currentLog, targetSets: targetSets, targetReps: targetReps, supportsWeight: exercise.supportsWeight)
            
        case .flexibility:
            return calculateFlexibilityProgression(currentLog: currentLog)
        }
    }
    
    private static func calculateWeightProgression(
        currentLog: ExerciseLog,
        targetSets: Int,
        targetReps: Int
    ) -> OverloadRecommendation {
        
        // Check if user completed all target reps in previous workout
        let completedTargetReps = currentLog.reps >= targetReps
        let completedTargetSets = currentLog.sets >= targetSets
        
        if completedTargetReps && completedTargetSets {
            // Progress by increasing weight (2.5-5% increase)
            let weightIncrease = currentLog.weight * 0.025 // 2.5% increase
            let suggestedWeight = roundToNearestPlate(currentLog.weight + weightIncrease)
            
            return OverloadRecommendation(
                strategy: .increaseWeight,
                suggestedWeight: suggestedWeight,
                suggestedReps: targetReps,
                suggestedSets: targetSets,
                explanation: "Great job! You completed all sets and reps. Increase weight by \(String(format: "%.1f", suggestedWeight - currentLog.weight))kg."
            )
        } else if !completedTargetReps {
            // Maintain weight, focus on completing reps
            return OverloadRecommendation(
                strategy: .maintainCurrent,
                suggestedWeight: currentLog.weight,
                suggestedReps: targetReps,
                suggestedSets: targetSets,
                explanation: "Focus on completing all \(targetReps) reps before increasing weight."
            )
        } else {
            // Completed reps but not all sets - add a set
            return OverloadRecommendation(
                strategy: .increaseSets,
                suggestedWeight: currentLog.weight,
                suggestedReps: targetReps,
                suggestedSets: min(targetSets + 1, 5), // Cap at 5 sets
                explanation: "Good progress! Try to complete one more set this time."
            )
        }
    }
    
    private static func calculateCardioProgression(
        currentLog: ExerciseLog,
        exercise: Exercise
    ) -> OverloadRecommendation {
        
        let metric = exercise.cardioMetric
        var explanation = ""
        var suggestedDuration = currentLog.duration
        var suggestedDistance = currentLog.distance
        
        switch metric {
        case .time:
            // Increase duration by 5-10%
            if let duration = currentLog.duration {
                suggestedDuration = duration * 1.05
                let additionalMinutes = Int((suggestedDuration! - duration) / 60)
                explanation = "Increase duration by \(additionalMinutes) minutes."
            }
            
        case .distance:
            // Increase distance by 5-10%
            if let distance = currentLog.distance {
                suggestedDistance = distance * 1.05
                explanation = "Increase distance by \(String(format: "%.1f", suggestedDistance! - distance)) \(currentLog.distanceUnit)."
            }
            
        case .both:
            // Alternate between improving time and distance
            if let duration = currentLog.duration, let distance = currentLog.distance {
                // Simple heuristic: if last workout focused on distance, now focus on time
                let pace = duration / distance // seconds per km/mile
                
                // Improve pace by 2%
                let newPace = pace * 0.98
                suggestedDuration = distance * newPace
                
                explanation = "Maintain distance but improve your pace by completing it faster."
            }
        }
        
        return OverloadRecommendation(
            strategy: .maintainCurrent,
            suggestedWeight: 0,
            suggestedReps: 0,
            suggestedSets: 1,
            explanation: explanation
        )
    }
    
    private static func calculateBodyweightProgression(
        currentLog: ExerciseLog,
        targetSets: Int,
        targetReps: Int,
        supportsWeight: Bool
    ) -> OverloadRecommendation {
        
        let completedTargetReps = currentLog.reps >= targetReps
        let completedTargetSets = currentLog.sets >= targetSets
        
        if completedTargetReps && completedTargetSets {
            if targetReps < 20 {
                // First try to increase reps
                return OverloadRecommendation(
                    strategy: .increaseReps,
                    suggestedWeight: currentLog.weight,
                    suggestedReps: targetReps + 2,
                    suggestedSets: targetSets,
                    explanation: "Great progress! Try for \(targetReps + 2) reps per set."
                )
            } else if supportsWeight {
                // If already doing high reps, add weight
                let suggestedWeight = currentLog.weight > 0 ? currentLog.weight + 2.5 : 2.5
                return OverloadRecommendation(
                    strategy: .increaseWeight,
                    suggestedWeight: suggestedWeight,
                    suggestedReps: 12, // Reset to moderate reps with weight
                    suggestedSets: targetSets,
                    explanation: "Excellent! Add \(String(format: "%.1f", suggestedWeight))kg and reduce reps."
                )
            } else {
                // Can't add weight, increase sets
                return OverloadRecommendation(
                    strategy: .increaseSets,
                    suggestedWeight: 0,
                    suggestedReps: targetReps,
                    suggestedSets: min(targetSets + 1, 5),
                    explanation: "Add another set to increase volume."
                )
            }
        } else {
            // Maintain current targets
            return OverloadRecommendation(
                strategy: .maintainCurrent,
                suggestedWeight: currentLog.weight,
                suggestedReps: targetReps,
                suggestedSets: targetSets,
                explanation: "Focus on completing all sets and reps with good form."
            )
        }
    }
    
    private static func calculateFlexibilityProgression(
        currentLog: ExerciseLog
    ) -> OverloadRecommendation {
        
        guard let duration = currentLog.duration else {
            return OverloadRecommendation(
                strategy: .maintainCurrent,
                suggestedWeight: 0,
                suggestedReps: 0,
                suggestedSets: 1,
                explanation: "Start with 5 minutes of stretching."
            )
        }
        
        // Increase duration by 30 seconds to 1 minute
        let additionalTime: TimeInterval = duration < 600 ? 30 : 60 // Less than 10 min: add 30s, else add 60s
        
        return OverloadRecommendation(
            strategy: .maintainCurrent,
            suggestedWeight: 0,
            suggestedReps: 0,
            suggestedSets: 1,
            explanation: "Increase hold time by \(Int(additionalTime)) seconds."
        )
    }
    
    // Helper function to round weight to nearest plate (2.5kg increments)
    private static func roundToNearestPlate(_ weight: Double) -> Double {
        return round(weight / 2.5) * 2.5
    }
}

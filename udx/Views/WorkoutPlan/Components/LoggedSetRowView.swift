import SwiftUI
import SwiftData

struct LoggedSetRowView: View {
    let workoutSet: WorkoutSet
    let plannedExercise: PlannedExercise
    let onUpdate: () -> Void
    
    var exerciseType: ExerciseType {
        plannedExercise.exercise.exerciseType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Set \(workoutSet.setNumber)")
                    .fontWeight(.semibold)
                
                if workoutSet.isWarmup {
                    Text("(Warm-up)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                Spacer()
                
                Text(formatSetDisplay())
                    .foregroundColor(.primary)
            }
            
            if let notes = workoutSet.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatSetDisplay() -> String {
        switch exerciseType {
        case .weight:
            return "\(workoutSet.reps) reps × \(String(format: "%.1f", workoutSet.weight)) kg"
        case .cardio:
            var parts: [String] = []
            if let duration = workoutSet.duration {
                parts.append(formatDuration(duration))
            }
            if let distance = workoutSet.distance {
                parts.append("\(String(format: "%.2f", distance)) \(workoutSet.distanceUnit)")
            }
            return parts.joined(separator: " • ")
        case .bodyweight:
            if workoutSet.weight > 0 {
                return "\(workoutSet.reps) reps (+\(String(format: "%.1f", workoutSet.weight)) kg)"
            } else {
                return "\(workoutSet.reps) reps"
            }
        case .flexibility:
            if let duration = workoutSet.duration {
                return formatDuration(duration)
            }
            return "No duration"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

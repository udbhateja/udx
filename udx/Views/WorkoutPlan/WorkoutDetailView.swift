import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @Bindable var plan: WorkoutPlan
    
    @State private var selectedExercise: PlannedExercise?
    @State private var showingEditMode = false
    @State private var showingExerciseSelection = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditWorkoutSheet = false
    @State private var exerciseToEdit: PlannedExercise?

    
    // For editing workout details
    @State private var editedName: String = ""
    @State private var editedDate: Date = Date()
    @State private var editedNotes: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                workoutInfoSection
                
                if showingEditMode {
                    Button("Add Exercises") {
                        showingExerciseSelection = true
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }
                
                if let exercises = plan.exercises?.sorted(by: { $0.order < $1.order }), !exercises.isEmpty {
                    exercisesSection(exercises: exercises)
                } else {
                    Text("No exercises added to this workout")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                
                if !plan.isCompleted {
                    Button {
                        plan.isCompleted = true
                        try? modelContext.save()
                        SwiftDataManager.shared.saveContext()
                    } label: {
                        Text("Mark Workout as Completed")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                } else {
                    Text("Workout Completed")
                        .bold()
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
        .navigationTitle(plan.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(showingEditMode ? "Done" : "Edit Exercises") {
                        showingEditMode.toggle()
                    }
                    
                    Button("Edit Workout Details") {
                        prepareForEditing()
                        showingEditWorkoutSheet = true
                    }
                    
                    Button(plan.isTemplate ? "Remove from Templates" : "Save as Template") {
                        plan.isTemplate.toggle()
                        try? modelContext.save()
                        SwiftDataManager.shared.saveContext()
                    }
                    
                    Button("Delete Workout", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            LogExerciseView(plannedExercise: exercise)
        }
        .sheet(isPresented: $showingExerciseSelection) {
            SelectExercisesView(plan: plan)
        }
        .sheet(isPresented: $showingEditWorkoutSheet) {
            editWorkoutView
        }
        .sheet(item: $exerciseToEdit) { exercise in
            EditPlannedExerciseView(plannedExercise: exercise)
        }

        .confirmationDialog(
            "Delete Workout",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteWorkout()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this workout? This action cannot be undone.")
        }
    }
    
    private var workoutInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if plan.isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                if plan.isTemplate {
                    Label("Template", systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if let notes = plan.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .padding(.vertical, 4)
            }
            
            // Display muscle groups derived from exercises
            let muscleGroups = getMuscleGroupsFromExercises()
            if !muscleGroups.isEmpty {
                Text("Target Muscles:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(muscleGroups.sorted(), id: \.self) { muscle in
                            Text(muscle)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.2), radius: 5)
        .padding(.horizontal)
    }
    
    private func exercisesSection(exercises: [PlannedExercise]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(exercises) { exercise in
                exerciseRow(exercise)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: .gray.opacity(0.2), radius: 3)
                    .padding(.horizontal)
                    .onTapGesture {
                        if showingEditMode {
                            exerciseToEdit = exercise
                        } else {
                            selectedExercise = exercise
                        }
                    }
            }
        }
    }
    
    private func exerciseRow(_ plannedExercise: PlannedExercise) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plannedExercise.exercise.name)
                    .font(.headline)
                
                Text(plannedExercise.exercise.muscleGroup)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Display based on exercise type
                VStack(alignment: .leading, spacing: 2) {
                    if let lastWorkout = plannedExercise.lastWorkout {
                        Text(formatLastWorkout(lastWorkout, for: plannedExercise.exercise))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(formatTargetDisplay(plannedExercise))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            if showingEditMode {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(plannedExercise.targetSets) sets")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                }
            } else {
                statusView(for: plannedExercise)
            }
        }
    }
    
    private func statusView(for exercise: PlannedExercise) -> some View {
        Group {
            if exercise.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if let logs = exercise.logs, !logs.isEmpty {
                Text("\(logs.count)/\(exercise.targetSets)")
                    .font(.caption)
                    .padding(6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var editWorkoutView: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    TextField("Workout Name", text: $editedName)
                    DatePicker("Date", selection: $editedDate, displayedComponents: .date)
                    
                    VStack(alignment: .leading) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $editedNotes)
                            .frame(height: 100)
                    }
                }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingEditWorkoutSheet = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWorkoutChanges()
                        showingEditWorkoutSheet = false
                    }
                }
            }
        }
    }
    
    private func prepareForEditing() {
        editedName = plan.name
        editedDate = plan.date
        editedNotes = plan.notes ?? ""
    }
    
    private func saveWorkoutChanges() {
        plan.name = editedName
        plan.date = editedDate
        plan.notes = editedNotes.isEmpty ? nil : editedNotes
        
        try? modelContext.save()
        SwiftDataManager.shared.saveContext()
    }
    
    private func deleteWorkout() {
        // Store the ID before dismissing
        let planID = plan.id
        
        // Dismiss the view first
        withAnimation {
            dismiss()
        }
        
        self.modelContext.delete(plan)
    }
    
    private func formatLastWorkout(_ log: ExerciseLog, for exercise: Exercise) -> String {
        switch exercise.exerciseType {
        case .weight:
            return "Last: \(log.sets) × \(log.reps) @ \(String(format: "%.1f", log.weight))kg"
        case .cardio:
            var parts: [String] = ["Last:"]
            if let duration = log.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                parts.append(String(format: "%d:%02d", minutes, seconds))
            }
            if let distance = log.distance {
                parts.append("\(String(format: "%.2f", distance)) \(log.distanceUnit)")
            }
            return parts.joined(separator: " ")
        case .bodyweight:
            if log.weight > 0 {
                return "Last: \(log.sets) × \(log.reps) (+\(String(format: "%.1f", log.weight))kg)"
            } else {
                return "Last: \(log.sets) × \(log.reps)"
            }
        case .flexibility:
            if let duration = log.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                return "Last: " + String(format: "%d:%02d", minutes, seconds)
            }
            return "Last: Completed"
        }
    }
    
    private func formatTargetDisplay(_ exercise: PlannedExercise) -> String {
        switch exercise.exercise.exerciseType {
        case .weight:
            var target = "Target: \(exercise.targetSets) × \(exercise.targetReps)"
            if exercise.lastWorkout != nil {
                target += " @ \(String(format: "%.1f", exercise.suggestedWeight))kg"
            }
            return target
        case .cardio:
            var parts: [String] = ["Target:"]
            if let duration = exercise.targetDuration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                parts.append(String(format: "%d:%02d", minutes, seconds))
            }
            if let distance = exercise.targetDistance {
                parts.append("\(String(format: "%.2f", distance)) \(exercise.distanceUnit)")
            }
            return parts.joined(separator: " ")
        case .bodyweight:
            var target = "Target: \(exercise.targetSets) × \(exercise.targetReps)"
            if exercise.exercise.supportsWeight && (exercise.targetWeight ?? 0) > 0 {
                target += " (+\(String(format: "%.1f", exercise.targetWeight!))kg)"
            }
            return target
        case .flexibility:
            if let duration = exercise.targetDuration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                return "Target: " + String(format: "%d:%02d", minutes, seconds)
            }
            return "Target: Not set"
        }
    }
    
    private func getMuscleGroupsFromExercises() -> Set<String> {
        var muscleGroups = Set<String>()
        
        if let exercises = plan.exercises {
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
        }
        
        return muscleGroups
    }
}

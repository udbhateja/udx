import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @Bindable var plan: WorkoutPlan
    
    @State private var showingExerciseLog = false
    @State private var selectedExercise: PlannedExercise?
    @State private var showingEditMode = false
    @State private var showingExerciseSelection = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditWorkoutSheet = false
    
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
                    
                    Button("Delete Workout", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingExerciseLog) {
            if let exercise = selectedExercise {
                LogExerciseView(plannedExercise: exercise)
            }
        }
        .sheet(isPresented: $showingExerciseSelection) {
            SelectExercisesView(plan: plan)
        }
        .sheet(isPresented: $showingEditWorkoutSheet) {
            editWorkoutView
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
            }
            
            if let notes = plan.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .padding(.vertical, 4)
            }
            
            if let muscles = plan.targetMuscles, !muscles.isEmpty {
                Text("Target Muscles:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(muscles) { muscle in
                            Text(muscle.name)
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
                        selectedExercise = exercise
                        showingExerciseLog = true
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
                
                if let lastWorkout = plannedExercise.lastWorkout {
                    Text("Last: \(lastWorkout.sets) × \(lastWorkout.reps) @ \(String(format: "%.1f", lastWorkout.weight))kg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Target: \(plannedExercise.targetSets) × \(plannedExercise.targetReps) @ \(String(format: "%.1f", plannedExercise.suggestedWeight))kg")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("Target: \(plannedExercise.targetSets) × \(plannedExercise.targetReps)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            statusView(for: plannedExercise)
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
}

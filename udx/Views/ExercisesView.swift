import SwiftUI
import SwiftData

struct ExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @Query private var majorMuscles: [MajorMuscle]
    @State private var showingAddExercise = false
    @State private var searchText = ""
    @State private var selectedMajorMuscle: MajorMuscle?
    
    var filteredExercises: [Exercise] {
        var filtered = exercises
        
        if let selected = selectedMajorMuscle {
            filtered = filtered.filter { exercise in
                // Check if the exercise has the selected major muscle
                if let majorMuscles = exercise.majorMuscles {
                    return majorMuscles.contains { $0.id == selected.id }
                } else {
                    return exercise.muscleGroup == selected.name
                }
            }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered
    }
    
    var groupedExercises: [String: [Exercise]] {
        Dictionary(grouping: filteredExercises) { $0.muscleGroup }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Muscle group filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button(action: { selectedMajorMuscle = nil }) {
                            Text("All")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedMajorMuscle == nil ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedMajorMuscle == nil ? .white : .primary)
                                .cornerRadius(20)
                        }
                        
                        ForEach(majorMuscles) { muscle in
                            Button(action: { selectedMajorMuscle = muscle }) {
                                Text(muscle.name)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedMajorMuscle?.id == muscle.id ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedMajorMuscle?.id == muscle.id ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                exerciseList
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddExercise = true }) {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
            }
        }
    }
    
    private var exerciseList: some View {
        List {
            ForEach(groupedExercises.keys.sorted(), id: \.self) { group in
                Section(header: Text(group)) {
                    ForEach(groupedExercises[group]!, id: \.id) { exercise in
                        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                    .font(.headline)
                                Text(exercise.allMinorMuscleNames)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        deleteExercises(for: group, at: indexSet)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
    }
    
    private func deleteExercises(for group: String, at offsets: IndexSet) {
        let exercisesToDelete = offsets.map { groupedExercises[group]![$0] }
        for exercise in exercisesToDelete {
            modelContext.delete(exercise)
        }
    }
}

struct ExercisesView_Previews: PreviewProvider {
    static var previews: some View {
        ExercisesView()
    }
}

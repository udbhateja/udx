import SwiftUI
import SwiftData

struct PlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutPlans: [WorkoutPlan]
    @State private var showingAddPlan = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(workoutPlans) { plan in
                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                        VStack(alignment: .leading) {
                            Text(plan.name)
                                .font(.headline)
                            Text(plan.date, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deletePlans)
            }
            .navigationTitle("Workout Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPlan = true }) {
                        Label("Add Plan", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlan) {
                AddPlanView()
            }
        }
    }
    
    private func deletePlans(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workoutPlans[index])
        }
    }
}

// Placeholder for plan detail view
struct PlanDetailView: View {
    var plan: WorkoutPlan
    
    var body: some View {
        Text("Plan Details: \(plan.name)")
            .navigationTitle(plan.name)
    }
}

// Placeholder for adding plan view
struct AddPlanView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Text("Add Plan View")
            .navigationTitle("New Workout Plan")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
    }
}

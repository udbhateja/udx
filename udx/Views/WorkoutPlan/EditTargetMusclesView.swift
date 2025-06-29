import SwiftUI

struct EditTargetMusclesView: View {
    @Environment(\.dismiss) private var dismiss
    
    let plan: WorkoutPlan
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "info.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                Text("Target Muscles")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Target muscles are now automatically determined from the exercises you add to your workout plan.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Text("Simply add exercises to your workout, and the app will track which muscle groups you're targeting.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Target Muscles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

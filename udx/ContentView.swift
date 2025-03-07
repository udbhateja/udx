//
//  ContentView.swift
//  udx
//
//  Created by Uday Bhateja on 07/03/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // Access the model context to check if we have data
    @Environment(\.modelContext) private var modelContext
    @Query private var majorMuscles: [MajorMuscle]
    
    var body: some View {
        TabView {
            ExercisesView()
                .tabItem {
                    Label("Exercises", systemImage: "dumbbell")
                }
            
            Text("Workout Plan View") // Replace with PlansView when it's ready
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.clipboard")
                }
            
            Text("Dashboard View") // Replace with DashboardView when it's ready
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            // Debug: print the container URL and if we have any data
            let container = modelContext.container
            if let url = container.configurations.first?.url {
                print("SwiftData container path: \(url.path)")
                print("Currently stored major muscles: \(majorMuscles.count)")
            }
            
            // If we have no muscles, let's add some defaults to make testing easier
            if majorMuscles.isEmpty {
                createDefaultMuscles()
            }
        }
    }
    
    private func createDefaultMuscles() {
        let defaultMuscles = [
            "Chest", "Back", "Shoulders", "Legs", "Arms", "Core", "Full Body"
        ]
        
        for muscleName in defaultMuscles {
            let muscle = MajorMuscle(name: muscleName)
            modelContext.insert(muscle)
            
            // Add some minor muscles for each major muscle
            switch muscleName {
            case "Chest":
                let minors = ["Upper Chest", "Middle Chest", "Lower Chest"]
                for minorName in minors {
                    let minor = MinorMuscle(name: minorName, majorMuscle: muscle)
                    modelContext.insert(minor)
                    if muscle.minorMuscles == nil {
                        muscle.minorMuscles = [minor]
                    } else {
                        muscle.minorMuscles?.append(minor)
                    }
                }
            case "Back":
                let minors = ["Upper Back", "Lats", "Lower Back"]
                for minorName in minors {
                    let minor = MinorMuscle(name: minorName, majorMuscle: muscle)
                    modelContext.insert(minor)
                    if muscle.minorMuscles == nil {
                        muscle.minorMuscles = [minor]
                    } else {
                        muscle.minorMuscles?.append(minor)
                    }
                }
            case "Shoulders":
                let minors = ["Front Deltoid", "Side Deltoid", "Rear Deltoid"]
                for minorName in minors {
                    let minor = MinorMuscle(name: minorName, majorMuscle: muscle)
                    modelContext.insert(minor)
                    if muscle.minorMuscles == nil {
                        muscle.minorMuscles = [minor]
                    } else {
                        muscle.minorMuscles?.append(minor)
                    }
                }
            default:
                break
            }
        }
        
        // Force save the context
        try? modelContext.save()
        print("Created default muscles")
    }
}

#Preview {
    ContentView()
}

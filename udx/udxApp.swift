//
//  udxApp.swift
//  udx
//
//  Created by Uday Bhateja on 07/03/25.
//

import SwiftUI
import SwiftData

@main
struct udxApp: App {
    let dataManager = SwiftDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            if let container = dataManager.createContainer() {
                ContentView()
                    .modelContainer(container)
                    .onAppear {
                        // Add default data if needed
                        dataManager.addDefaultMusclesIfNeeded()
                    }
            } else {
                Text("Failed to initialize database")
                    .foregroundColor(.red)
            }
        }
    }
}

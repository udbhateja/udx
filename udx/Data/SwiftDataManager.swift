import Foundation
import SwiftData
import SwiftUI
import OSLog

class SwiftDataManager {
    static let shared = SwiftDataManager()
    private let logger = Logger(subsystem: "com.udx.app", category: "SwiftDataManager")
    
    var container: ModelContainer?
    var context: ModelContext?
    
    var modelContext: ModelContext? {
        return context
    }
    
    private init() {}
    
    func createContainer() -> ModelContainer? {
        let schema = Schema([
            Exercise.self,
            ExerciseLog.self,
            MajorMuscle.self,
            MinorMuscle.self,
            WorkoutPlan.self,
            PlannedExercise.self,  // Make sure it's PlannedExercise, not PlanExercise
            WorkoutSet.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            let url = URL.applicationSupportDirectory.appending(path: "UdxModels.sqlite")
            logger.debug("Using database at: \(url.path(percentEncoded: false))")
            
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, configurations: [config])
            self.container = container
            self.context = ModelContext(container)
            
            logger.info("SwiftData container created successfully")
            return container
        } catch {
            logger.error("Failed to create SwiftData container: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveContext() {
        guard let context = self.context else {
            logger.warning("No context available to save")
            return
        }
        
        do {
            try context.save()
            logger.debug("Context saved successfully")
        } catch {
            logger.error("Error saving context: \(error.localizedDescription)")
        }
    }
    
    func addDefaultMusclesIfNeeded() {
        guard let context = self.context else { return }
        
        // Check if we already have muscles
        let descriptor = FetchDescriptor<MajorMuscle>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else {
            let count = try? context.fetchCount(descriptor)
            logger.info("Default muscles not needed, found \(count ?? 0) existing muscles")
            return
        }
        
        logger.info("Adding default muscles")
        let defaultMuscles = [
            "Chest", "Back", "Shoulders", "Legs", "Arms", "Core", "Full Body"
        ]
        
        for muscleName in defaultMuscles {
            let muscle = MajorMuscle(name: muscleName)
            context.insert(muscle)
            
            // Add some minor muscles for each major muscle
            switch muscleName {
            case "Chest":
                addMinorMuscles(["Upper Chest", "Middle Chest", "Lower Chest"], to: muscle, context: context)
            case "Back":
                addMinorMuscles(["Upper Back", "Lats", "Lower Back"], to: muscle, context: context)
            case "Shoulders":
                addMinorMuscles(["Front Deltoid", "Side Deltoid", "Rear Deltoid"], to: muscle, context: context)
            case "Arms":
                addMinorMuscles(["Biceps", "Triceps", "Forearms"], to: muscle, context: context)
            default:
                break
            }
        }
        
        // Force save the context
        saveContext()
        logger.info("Default muscles created and saved")
    }
    
    private func addMinorMuscles(_ names: [String], to major: MajorMuscle, context: ModelContext) {
        for name in names {
            let minor = MinorMuscle(name: name, majorMuscle: major)
            context.insert(minor)
            if major.minorMuscles == nil {
                major.minorMuscles = [minor]
            } else {
                major.minorMuscles?.append(minor)
            }
        }
    }
}

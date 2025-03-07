import Foundation
import SwiftData

@Model
final class MajorMuscle {
    var name: String
    var minorMuscles: [MinorMuscle]?
    @Relationship var exercises: [Exercise]?
    
    init(name: String, minorMuscles: [MinorMuscle]? = nil) {
        self.name = name
        self.minorMuscles = minorMuscles
    }
}

@Model
final class MinorMuscle {
    var name: String
    var majorMuscle: MajorMuscle?
    @Relationship var exercises: [Exercise]?
    
    init(name: String, majorMuscle: MajorMuscle? = nil) {
        self.name = name
        self.majorMuscle = majorMuscle
    }
}

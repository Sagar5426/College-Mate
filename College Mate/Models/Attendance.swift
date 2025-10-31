import Foundation
import SwiftData

@Model
class Attendance {
    // 1. Added default values
    var id: UUID = UUID()
    var totalClasses: Int = 0
    var attendedClasses: Int = 0
    var minimumPercentageRequirement: Double = 75.0 // User-defined requirement
    
    // 2. Added inverse relationship
    var subject: Subject?
    
    init(totalClasses: Int, attendedClasses: Int, minimumPercentageRequirement: Double = 75.0) {
        self.id = UUID()
        self.totalClasses = totalClasses
        self.attendedClasses = attendedClasses
        self.minimumPercentageRequirement = minimumPercentageRequirement
    }
    
    // 3. Added default init for CloudKit
    init() {}
    
    // Computed property for attendance percentage
    var percentage: Double {
        guard totalClasses > 0 else { return 0 }
        return (Double(attendedClasses) / Double(totalClasses)) * 100
    }
}

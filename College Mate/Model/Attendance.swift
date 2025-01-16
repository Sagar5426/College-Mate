import Foundation
import SwiftData

@Model
class Attendance {
    var id: UUID
    var totalClasses: Int
    var attendedClasses: Int
    var minimumPercentageRequirement: Double // User-defined requirement
    
    init(totalClasses: Int, attendedClasses: Int, minimumPercentageRequirement: Double = 75.0) {
        self.id = UUID()
        self.totalClasses = totalClasses
        self.attendedClasses = attendedClasses
        self.minimumPercentageRequirement = minimumPercentageRequirement
    }
    
    // Computed property for attendance percentage
    var percentage: Double {
        guard totalClasses > 0 else { return 0 }
        return (Double(attendedClasses) / Double(totalClasses)) * 100
    }
    
    // Calculate the number of additional classes required to meet the minimum percentage
    var requiredClassesToMeetRequirement: Int {
        guard minimumPercentageRequirement > percentage else { return 0 }
        
        let requiredAttendedClasses = Int(ceil(minimumPercentageRequirement / 100.0 * Double(totalClasses)))
        
        // Calculate additional classes required
        let additionalClassesNeeded = max(0, requiredAttendedClasses - attendedClasses)
        
        return additionalClassesNeeded
    }

}


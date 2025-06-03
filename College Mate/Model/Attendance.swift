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
    

}


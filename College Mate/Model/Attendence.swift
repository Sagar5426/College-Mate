import Foundation
import SwiftData

@Model
class Attendance {
    var id: UUID
    var totalClasses: Int
    var attendedClasses: Int
    
    
    init(totalClasses: Int, attendedClasses: Int) {
        self.id = UUID()
        self.totalClasses = totalClasses
        self.attendedClasses = attendedClasses
    }
    
    var attendancePercentage: Double {
        guard totalClasses > 0 else { return 0 }
        return (Double(attendedClasses) / Double(totalClasses)) * 100
    }
}


import Foundation
import SwiftData

@Model
class Subject {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade) var schedules: [Schedule] = []
    @Relationship(deleteRule: .cascade) var attendance: Attendance
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.attendance = Attendance(totalClasses: 0, attendedClasses: 0)
    }
}

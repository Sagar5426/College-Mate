import Foundation
import SwiftData

@Model
class Subject {
    var id: UUID
    var name: String
    var numberOfNotes: Int
    var startDateOfSubject: Date
    var schedules: [Schedule]
    var attendance: Attendance
    
    init(name: String, numberOfNotes: Int = 0,startDateOfSubject: Date = .now, schedules: [Schedule] = [], attendance: Attendance = Attendance(totalClasses: 0, attendedClasses: 0)) {
        self.id = UUID()
        self.name = name
        self.numberOfNotes = numberOfNotes
        self.startDateOfSubject = startDateOfSubject
        self.schedules = schedules
        self.attendance = attendance
    }
    
    
}

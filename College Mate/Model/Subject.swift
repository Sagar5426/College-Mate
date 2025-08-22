import Foundation
import SwiftData

@Model
class Subject {
    var id: UUID
    var name: String
    var startDateOfSubject: Date
    @Relationship(deleteRule: .cascade) var schedules: [Schedule]
    @Relationship(deleteRule: .cascade) var attendance: Attendance
    @Relationship(deleteRule: .cascade) var notes: [Note]
    var logs: [AttendanceLogEntry] = []
    
    // Each subject now has a list of its unique attendance records.
    @Relationship(deleteRule: .cascade, inverse: \AttendanceRecord.subject)
    var records: [AttendanceRecord] = []

    init(name: String, startDateOfSubject: Date = .now, schedules: [Schedule] = [], attendance: Attendance = Attendance(totalClasses: 0, attendedClasses: 0), notes: [Note] = []) {
        self.id = UUID()
        self.name = name
        self.startDateOfSubject = startDateOfSubject
        self.schedules = schedules
        self.attendance = attendance
        self.notes = notes
    }
}




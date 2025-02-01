import Foundation
import SwiftData

@Model
class Subject {
    var id: UUID
    var name: String
    var startDateOfSubject: Date
    var schedules: [Schedule]
    var attendance: Attendance
    var notes: [Note] // New property to store notes

    init(name: String, startDateOfSubject: Date = .now, schedules: [Schedule] = [], attendance: Attendance = Attendance(totalClasses: 0, attendedClasses: 0), notes: [Note] = []) {
        self.id = UUID()
        self.name = name
        self.startDateOfSubject = startDateOfSubject
        self.schedules = schedules
        self.attendance = attendance
        self.notes = notes
    }
}





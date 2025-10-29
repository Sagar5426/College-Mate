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
    
    // Folder system for organizing files
    @Relationship(deleteRule: .cascade, inverse: \Folder.subject)
    var rootFolders: [Folder] = []
    
    // File metadata for tracking files and favorites
    @Relationship(deleteRule: .cascade, inverse: \FileMetadata.subject)
    var fileMetadata: [FileMetadata] = []

    // ADDED: Property to store the scratchpad note
    var ImportantTopicsNote: String = ""

    init(name: String, startDateOfSubject: Date = .now, schedules: [Schedule] = [], attendance: Attendance = Attendance(totalClasses: 0, attendedClasses: 0), notes: [Note] = []) {
        self.id = UUID()
        self.name = name
        self.startDateOfSubject = startDateOfSubject
        self.schedules = schedules
        self.attendance = attendance
        self.notes = notes
    }
}

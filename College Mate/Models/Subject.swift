import Foundation
import SwiftData

@Model
class Subject {
    // 1. Added default values
    var id: UUID = UUID()
    var name: String = ""
    var startDateOfSubject: Date = Date()
    var logs: [AttendanceLogEntry] = []
    var ImportantTopicsNote: String = ""

    // 2. Updated relationships to be OPTIONAL and have INVERSE
    @Relationship(deleteRule: .cascade, inverse: \Schedule.subject)
    var schedules: [Schedule]? // Was [Schedule]
    
    @Relationship(deleteRule: .cascade, inverse: \Attendance.subject)
    var attendance: Attendance? // Was Attendance
    
    @Relationship(deleteRule: .cascade, inverse: \Note.subject)
    var notes: [Note]? // Was [Note]
    
    @Relationship(deleteRule: .cascade, inverse: \AttendanceRecord.subject)
    var records: [AttendanceRecord]? // Was [AttendanceRecord]
    
    @Relationship(deleteRule: .cascade, inverse: \Folder.subject)
    var rootFolders: [Folder]? // Was [Folder]
    
    @Relationship(deleteRule: .cascade, inverse: \FileMetadata.subject)
    var fileMetadata: [FileMetadata]? // Was [FileMetadata]

    // 3. Kept your custom init, but updated to match optional properties
    init(name: String, startDateOfSubject: Date = .now, schedules: [Schedule]? = [], attendance: Attendance? = Attendance(totalClasses: 0, attendedClasses: 0), notes: [Note]? = []) {
        self.id = UUID()
        self.name = name
        self.startDateOfSubject = startDateOfSubject
        self.schedules = schedules
        self.attendance = attendance
        self.notes = notes
        // Note: 'records', 'rootFolders', 'fileMetadata' will default to nil
    }
    
    // 4. Added default init for CloudKit
    init() {}
}

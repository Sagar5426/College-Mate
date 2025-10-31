import Foundation
import SwiftData

@Model
class AttendanceRecord {
    // 1. Added default values
    var id: UUID = UUID()
    var date: Date = Date()
    var status: String = ""
    var classTimeID: UUID = UUID()
    var isHoliday: Bool = false
    
    // Inverse relationship already exists
    var subject: Subject?
    
    init(date: Date, status: String, classTimeID: UUID, isHoliday: Bool = false) {
        self.id = UUID()
        self.date = date
        self.status = status
        self.classTimeID = classTimeID
        self.isHoliday = isHoliday
    }
    
    // 2. Added default init for CloudKit
    init() {}
}

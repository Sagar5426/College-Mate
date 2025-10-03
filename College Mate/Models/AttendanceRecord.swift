import Foundation
import SwiftData

@Model
class AttendanceRecord {
    var id: UUID
    var date: Date
    var status: String
    var classTimeID: UUID
    var subject: Subject?
    var isHoliday: Bool
    
    init(date: Date, status: String, classTimeID: UUID, isHoliday: Bool = false) {
        self.id = UUID()
        self.date = date
        self.status = status
        self.classTimeID = classTimeID
        self.isHoliday = isHoliday
    }
}

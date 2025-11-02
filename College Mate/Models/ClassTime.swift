import Foundation
import SwiftData

@Model
class ClassTime {
    var id: UUID = UUID()
    
    var date: Date?
    var startTime: Date?
    var endTime: Date?
    
    var schedule: Schedule?
    
    init(startTime: Date? = nil, endTime: Date? = nil, date: Date? = Date()) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.date = date
    }
    
    init() {}
}

// Define a custom struct for class times
struct ClassPeriodTime: Hashable {
    var startTime: Date?
    var endTime: Date?
}

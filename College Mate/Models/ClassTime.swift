import Foundation
import SwiftData

@Model
class ClassTime {
    // 1. Added default value
    var id: UUID = UUID()
    
    // These were already optional, which is good
    var date: Date?
    var startTime: Date?
    var endTime: Date?
    
    // Inverse relationship already exists
    var schedule: Schedule?
    
    init(startTime: Date? = nil, endTime: Date? = nil, date: Date? = Date()) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.date = date
    }
    
    // 2. Added default init for CloudKit
    init() {}
}

// Define a custom struct for class times
struct ClassPeriodTime: Hashable {
    var startTime: Date?
    var endTime: Date?
}

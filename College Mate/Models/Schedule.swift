import Foundation
import SwiftUI
import SwiftData

@Model
class Schedule {
    // 1. Added default values
    var id: UUID = UUID()
    var day: String = ""
    
    // 2. Made relationship optional
    var classTimes: [ClassTime]?
    
    // 3. Added inverse relationship
    var subject: Subject?
    
    init(day: String, classTimes: [ClassTime]? = []) { // Updated to optional
        self.id = UUID()
        self.day = day
        self.classTimes = classTimes
    }
    
    // 4. Added default init for CloudKit
    init() {}
}

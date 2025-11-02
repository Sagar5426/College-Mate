import Foundation
import SwiftUI
import SwiftData

@Model
class Schedule {
    var id: UUID = UUID()
    var day: String = ""
    
    var classTimes: [ClassTime]?
    
    var subject: Subject?
    
    init(day: String, classTimes: [ClassTime]? = []) { 
        self.id = UUID()
        self.day = day
        self.classTimes = classTimes
    }
    
    
    init() {}
}

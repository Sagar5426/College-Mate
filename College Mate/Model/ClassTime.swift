//
//  ClassTime.swift
//  College Mate
//
//  Created by Sagar Jangra on 04/01/2025.
//

import Foundation
import SwiftData

@Model
class ClassTime {
    var id: UUID
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
}

// Define a custom struct for class times
struct ClassPeriodTime: Hashable {
    var startTime: Date?
    var endTime: Date?
}

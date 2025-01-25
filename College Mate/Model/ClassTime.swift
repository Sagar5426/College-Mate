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
    var label: String
    var date: Date?
    var lastUpdatedDate: Date?
    var startTime: Date?
    var endTime: Date?
    var schedule: Schedule? // Optional relationship back to `Schedule` (if needed)
    var isAttended: Bool
    
    init(startTime: Date? = nil, endTime: Date? = nil, isAttended: Bool = false, label: String = "Canceled", lastUpdatedDate: Date? = nil, date: Date? = Date()) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.isAttended = isAttended
        self.label = label
        self.lastUpdatedDate = lastUpdatedDate
        self.date = date
    }
}

// Define a custom struct for class times
struct ClassPeriodTime: Hashable {
    var startTime: Date?
    var endTime: Date?
}

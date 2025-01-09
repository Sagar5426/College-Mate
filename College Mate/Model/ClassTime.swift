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
    var startTime: Date?
    var endTime: Date?
    var schedule: Schedule? // Optional relationship back to `Schedule` (if needed)
    
    init(startTime: Date? = nil, endTime: Date? = nil) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
    }
}

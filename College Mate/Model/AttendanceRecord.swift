//
//  AttendanceRecord.swift
//  College Mate
//
//  Created by Sagar Jangra on 22/08/2025.
//

import Foundation
import SwiftData

@Model
class AttendanceRecord {
    // A unique ID for the record itself.
    var id: UUID
    
    // The specific date this record is for (e.g., "2025-08-25").
    var date: Date
    
    // The status for this specific class on this specific date.
    var status: String
    
    // A link back to the ClassTime template this record is an instance of.
    var classTimeID: UUID
    
    // The subject this record belongs to.
    var subject: Subject?
    
    init(date: Date, status: String, classTimeID: UUID) {
        self.id = UUID()
        self.date = date
        self.status = status
        self.classTimeID = classTimeID
    }
}

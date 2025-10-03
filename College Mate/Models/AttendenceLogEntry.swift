//
//  AttendenceLogEntry.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/06/2025.
//

import Foundation

struct AttendanceLogEntry: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let subjectName: String
    let action: String
}


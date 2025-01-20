//
//  Note.swift
//  College Mate
//
//  Created by Sagar Jangra on 20/01/2025.
//


import Foundation
import SwiftData

@Model
class Note {
    var id: UUID
    var title: String
    var type: NoteType
    var content: Data
    var createdDate: Date

    init(title: String, type: NoteType, content: Data, createdDate: Date = .now) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.content = content
        self.createdDate = createdDate
    }
}

enum NoteType: String, Codable {
    case pdf
    case image
}

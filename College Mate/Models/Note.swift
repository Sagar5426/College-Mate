import Foundation
import SwiftData

@Model
class Note {
    // 1. Added default values
    var id: UUID = UUID()
    var title: String = ""
    var type: NoteType = NoteType.pdf
    
    var content: Data = Data()
    var createdDate: Date = Date()
    
    // 2. Added inverse relationship
    var subject: Subject?

    init(title: String, type: NoteType, content: Data, createdDate: Date = .now) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.content = content
        self.createdDate = createdDate
    }
    
    // 3. Added default init for CloudKit
    init() {}
}

enum NoteType: String, Codable {
    case pdf
    case image
}


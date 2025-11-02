import Foundation
import SwiftData

@Model
class Note {
    var id: UUID = UUID()
    var title: String = ""
    var type: NoteType = NoteType.pdf
    
    var content: Data = Data()
    var createdDate: Date = Date()
    
    var subject: Subject?

    init(title: String, type: NoteType, content: Data, createdDate: Date = .now) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.content = content
        self.createdDate = createdDate
    }
    
    
    init() {}
}

enum NoteType: String, Codable {
    case pdf
    case image
}


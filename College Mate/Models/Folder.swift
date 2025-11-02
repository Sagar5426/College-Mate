import Foundation
import SwiftData

@Model
class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var createdDate: Date = Date()
    var isFavorite: Bool = false
    
    var parentFolder: Folder?
    var subject: Subject?
    
    @Relationship(deleteRule: .cascade, inverse: \Folder.parentFolder)
    var subfolders: [Folder]?
    
    @Relationship(deleteRule: .cascade, inverse: \FileMetadata.folder)
    var files: [FileMetadata]?
    
    init(name: String, parentFolder: Folder? = nil, subject: Subject? = nil, isFavorite: Bool = false) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.isFavorite = isFavorite
        self.parentFolder = parentFolder
        self.subject = subject
    }
    
    init() {}
    
    var fullPath: String {
        if let parent = parentFolder {
            return "\(parent.fullPath)/\(name)"
        } else {
            return name
        }
    }
    
    var isRootFolder: Bool {
        return parentFolder == nil
    }
}

import Foundation
import SwiftData

@Model
class Folder {
    // 1. Added default values
    var id: UUID = UUID()
    var name: String = ""
    var createdDate: Date = Date()
    var isFavorite: Bool = false
    
    // Inverse relationships already exist and are optional
    var parentFolder: Folder?
    var subject: Subject?
    
    // 2. Made relationships optional
    @Relationship(deleteRule: .cascade, inverse: \Folder.parentFolder)
    var subfolders: [Folder]? // Was [Folder]
    
    @Relationship(deleteRule: .cascade, inverse: \FileMetadata.folder)
    var files: [FileMetadata]? // Was [FileMetadata]
    
    init(name: String, parentFolder: Folder? = nil, subject: Subject? = nil, isFavorite: Bool = false) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.isFavorite = isFavorite
        self.parentFolder = parentFolder
        self.subject = subject
    }
    
    // 3. Added default init for CloudKit
    init() {}
    
    // Computed property to get full path
    var fullPath: String {
        if let parent = parentFolder {
            return "\(parent.fullPath)/\(name)"
        } else {
            return name
        }
    }
    
    // Helper to check if this is a root folder
    var isRootFolder: Bool {
        return parentFolder == nil
    }
}

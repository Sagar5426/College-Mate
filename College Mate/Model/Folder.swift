//
//  Folder.swift
//  College Mate
//
//  Created by Sagar Jangra on 13/09/2025.
//

import Foundation
import SwiftData

@Model
class Folder {
    var id: UUID
    var name: String
    var createdDate: Date
    var isFavorite: Bool // New property to track favorite status
    var parentFolder: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Folder.parentFolder)
    var subfolders: [Folder] = []
    @Relationship(deleteRule: .cascade, inverse: \FileMetadata.folder)
    var files: [FileMetadata] = []
    
    // Reference to the subject this folder belongs to
    var subject: Subject?
    
    init(name: String, parentFolder: Folder? = nil, subject: Subject? = nil, isFavorite: Bool = false) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.isFavorite = isFavorite
        self.parentFolder = parentFolder
        self.subject = subject
    }
    
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

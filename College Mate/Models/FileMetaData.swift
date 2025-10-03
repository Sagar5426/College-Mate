//
//  FileMetaData.swift
//  College Mate
//
//  Created by Sagar Jangra on 13/09/2025.
//

import Foundation
import SwiftData

@Model
class FileMetadata {
    var id: UUID
    var fileName: String
    var fileType: FileType
    var createdDate: Date
    var isFavorite: Bool
    var relativePath: String // Path relative to subject folder
    var fileSize: Int64
    
    // Relationship to folder
    var folder: Folder?
    
    // Relationship to subject
    var subject: Subject?
    
    init(fileName: String, fileType: FileType, relativePath: String, fileSize: Int64 = 0, isFavorite: Bool = false, folder: Folder? = nil, subject: Subject? = nil) {
        self.id = UUID()
        self.fileName = fileName
        self.fileType = fileType
        self.createdDate = Date()
        self.isFavorite = isFavorite
        self.relativePath = relativePath
        self.fileSize = fileSize
        self.folder = folder
        self.subject = subject
    }
    
    // Get the full file URL
    func getFileURL() -> URL? {
        guard let subject = self.subject else { return nil }
        let subjectFolder = FileDataService.subjectFolder(for: subject)
        return subjectFolder.appendingPathComponent(relativePath)
    }
}

enum FileType: String, Codable, CaseIterable {
    case pdf = "pdf"
    case image = "image"
    case docx = "docx"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .image: return "Image"
        case .docx: return "Document"
        case .unknown: return "File"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .pdf: return "doc.richtext.fill"
        case .image: return "photo.fill"
        case .docx: return "doc.text.fill"
        case .unknown: return "doc.fill"
        }
    }
    
    static func from(fileExtension: String) -> FileType {
        let ext = fileExtension.lowercased()
        switch ext {
        case "pdf": return .pdf
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff": return .image
        case "docx", "doc": return .docx
        default: return .unknown
        }
    }
}

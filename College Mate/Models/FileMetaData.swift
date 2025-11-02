import Foundation
import SwiftData

@Model
class FileMetadata {
    // 1. Added default values
    var id: UUID = UUID()
    var fileName: String = ""
    
    var fileType: FileType = FileType.unknown
    
    var createdDate: Date = Date()
    var isFavorite: Bool = false
    var relativePath: String = ""
    var fileSize: Int64 = 0
    
    // Relationships to folder/subject already exist and are optional
    var folder: Folder?
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
    
    // 2. Added default init for CloudKit
    init() {}
    
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


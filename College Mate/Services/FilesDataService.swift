import Foundation
import SwiftData

struct FileDataService {
    /// Attempts to resolve the App Group identifier without a hard dependency on a specific type.
    /// Priority:
    /// 1. SharedAppGroup.id if the type exists at runtime
    /// 2. Info.plist key `AppGroupIdentifier`
    /// 3. nil (caller should fallback to Documents)
    /// NOTE: This function is no longer used by `baseFolder` but is left for reference.
    private static func resolvedAppGroupID() -> String? {
        // Try to access SharedAppGroup.id via reflection to avoid compile-time dependency
        if let sharedAppGroupType: AnyObject.Type = NSClassFromString("SharedAppGroup") {
            // Attempt to read a static `id` property via KVC
            let mirror = Mirror(reflecting: sharedAppGroupType)
            // If direct reflection fails, try known accessor through NSObject bridging
            if let value = (sharedAppGroupType as? NSObject.Type)?.value(forKey: "id") as? String {
                return value
            }
            // Fallback: check for a global function `id` is not feasible; ignore
            _ = mirror // keep mirror referenced to avoid warnings
        }
        // Try Info.plist key
        if let infoDict = Bundle.main.infoDictionary,
           let appGroup = infoDict["AppGroupIdentifier"] as? String,
           !appGroup.isEmpty {
            return appGroup
        }
        return nil
    }

    // --- THIS IS THE CRITICAL FIX ---
    // We hardcode the App Group ID string. Your entitlements file makes this safe.
    // The old `resolvedAppGroupID()` function was the bug.
    private static let appGroupID = "group.com.sagarjangra.College-Mate"
    
    private static let iCloudContainerID = "iCloud.com.sagarjangra.College-Mate"

    static let baseFolder: URL = {
        // Priority 1: Use the iCloud Drive container if available
                if let cloudURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerID)?
                                            .appendingPathComponent("Documents") // Standard subfolder for user files
                                            .appendingPathComponent("Subjects", isDirectory: true) {
                    
                    if !FileManager.default.fileExists(atPath: cloudURL.path) {
                        try? FileManager.default.createDirectory(at: cloudURL, withIntermediateDirectories: true)
                    }
                    print("[FileDataService] Using iCloud Drive URL: \(cloudURL.path)")
                    return cloudURL
                    
                } else {
                    // Fallback 2: Use App Group (if iCloud is logged out or disabled)
                    // Files will not sync, but the app will still work locally.
                    print("[FileDataService] WARNING: iCloud container not found. Falling back to App Group.")
                    if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                        let base = groupURL.appendingPathComponent("Subjects", isDirectory: true)
                        if !FileManager.default.fileExists(atPath: base.path) {
                            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
                        }
                        print("[FileDataService] Using App Group URL: \(base.path)")
                        return base
                    } else {
                        // Fallback 3: Documents directory (original fallback)
                        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                        let base = paths[0].appendingPathComponent("Subjects", isDirectory: true)
                        if !FileManager.default.fileExists(atPath: base.path) {
                            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
                        }
                        print("[FileDataService] WARNING: App Group not found. Falling back to Documents directory: \(base.path)")
                        return base
                    }
                }
    }()

    static func subjectFolder(for subject: Subject) -> URL {
        return baseFolder.appendingPathComponent(subject.name, isDirectory: true)
    }
    
    static func createSubjectFolder(for subject: Subject) {
        let folderURL = subjectFolder(for: subject)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    static func deleteSubjectFolder(for subject: Subject) {
        let folderURL = subjectFolder(for: subject)
        try? FileManager.default.removeItem(at: folderURL)
    }

    // MARK: - New folder-based operations
    
    /// Create a physical folder on disk for a Folder model
    static func createFolder(named name: String, in parentFolder: Folder?, for subject: Subject) -> URL? {
        let parentURL: URL
        if let parent = parentFolder {
            parentURL = getFolderURL(for: parent, in: subject)
        } else {
            parentURL = subjectFolder(for: subject)
        }
        
        let folderURL = parentURL.appendingPathComponent(name, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            return folderURL
        } catch {
            print("Error creating folder: \(error)")
            return nil
        }
    }
    
    /// Get the physical URL for a folder
    static func getFolderURL(for folder: Folder, in subject: Subject) -> URL {
        let subjectURL = subjectFolder(for: subject)
        return subjectURL.appendingPathComponent(folder.fullPath, isDirectory: true)
    }
    
    /// Save file to a specific folder
    static func saveFile(data: Data, fileName: String, to folder: Folder?, in subject: Subject, modelContext: ModelContext) -> FileMetadata? {
        createSubjectFolder(for: subject)
        
        let folderURL: URL
        let relativePath: String
        
        if let folder = folder {
            folderURL = getFolderURL(for: folder, in: subject)
            relativePath = "\(folder.fullPath)/\(fileName)"
            
            // Ensure folder exists on disk
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                do {
                    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Error creating folder: \(error)")
                    return nil
                }
            }
        } else {
            folderURL = subjectFolder(for: subject)
            relativePath = fileName
        }
        
        let fileURL = folderURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            
            // Create FileMetadata
            let fileExtension = (fileName as NSString).pathExtension
            let fileType = FileType.from(fileExtension: fileExtension)
            let fileSize = Int64(data.count)
            
            let metadata = FileMetadata(
                fileName: fileName,
                fileType: fileType,
                relativePath: relativePath,
                fileSize: fileSize,
                folder: folder,
                subject: subject
            )
            
            modelContext.insert(metadata)
            return metadata
            
        } catch {
            print("Error saving file: \(error)")
            return nil
        }
    }
    
    /// Move file from one folder to another
    static func moveFile(_ fileMetadata: FileMetadata, to targetFolder: Folder?, in subject: Subject) -> Bool {
        guard let currentURL = fileMetadata.getFileURL() else {
            print("Error: Could not get current URL for the file to move.")
            return false
        }
        
        let targetURL: URL
        let newRelativePath: String
        
        if let targetFolder = targetFolder {
            let targetFolderURL = getFolderURL(for: targetFolder, in: subject)
            targetURL = targetFolderURL.appendingPathComponent(fileMetadata.fileName)
            newRelativePath = "\(targetFolder.fullPath)/\(fileMetadata.fileName)"
        } else {
            targetURL = subjectFolder(for: subject).appendingPathComponent(fileMetadata.fileName)
            newRelativePath = fileMetadata.fileName
        }
        
        do {
            try FileManager.default.moveItem(at: currentURL, to: targetURL)
            fileMetadata.relativePath = newRelativePath
            fileMetadata.folder = targetFolder
            return true
        } catch {
            print("Error moving file: \(error)")
            return false
        }
    }
    
    /// Delete a folder and all its contents
    static func deleteFolder(_ folder: Folder, in subject: Subject) -> Bool {
        let folderURL = getFolderURL(for: folder, in: subject)
        
        do {
            try FileManager.default.removeItem(at: folderURL)
            return true
        } catch {
            print("Error deleting folder: \(error)")
            return false
        }
    }
    
    // Legacy loadFiles for migration
    static func loadFiles(from subject: Subject) -> [URL] {
        let folderURL = subjectFolder(for: subject)
        guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { !$0.hasDirectoryPath } // Filter out directories
    }
    
    /// Migrate existing files to the new folder system
    static func migrateExistingFiles(for subject: Subject, modelContext: ModelContext) {
        let existingFiles = loadFiles(from: subject)
        
        for fileURL in existingFiles {
            let fileName = fileURL.lastPathComponent
            
            // Check if metadata already exists for this file in this subject
            // Use a simple predicate on fileName only to avoid optional relationship chaining in the predicate,
            // then filter by subject in memory.
            let fetchDescriptor = FetchDescriptor<FileMetadata>(
                predicate: #Predicate { $0.fileName == fileName }
            )
            let countMatchesForSubject: Int
            if let results = try? modelContext.fetch(fetchDescriptor) {
                countMatchesForSubject = results.filter { $0.subject?.id == subject.id }.count
            } else {
                countMatchesForSubject = 0
            }
            
            if countMatchesForSubject == 0 {
                // Create metadata for existing file
                let fileExtension = fileURL.pathExtension
                let fileType = FileType.from(fileExtension: fileExtension)
                let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

                let metadata = FileMetadata(
                    fileName: fileName,
                    fileType: fileType,
                    relativePath: fileName,
                    fileSize: Int64(fileSize),
                    folder: nil,
                    subject: subject
                )
                modelContext.insert(metadata)
            }
        }
    }
}


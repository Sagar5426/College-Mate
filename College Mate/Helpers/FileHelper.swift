import Foundation

struct FileHelper {
    static let baseFolder: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Subjects", isDirectory: true)
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

    static func saveFile(data: Data, fileName: String, to subject: Subject) -> URL? {
        createSubjectFolder(for: subject)
        let fileURL = subjectFolder(for: subject).appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving file: \(error)")
            return nil
        }
    }
    
    static func loadFiles(from subject: Subject) -> [URL] {
        let folderURL = subjectFolder(for: subject)
        guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else { return [] }
        return files
    }
}

//import Foundation
//
//class FileManagerHelper {
//    static let shared = FileManagerHelper()
//
//    private init() {}
//
//    // Create a folder for PDFs in the app's Documents directory
//    func createAppFolder(named folderName: String) -> URL {
//        let fileManager = FileManager.default
//        let documentsDirectory = getDocumentsDirectory()
//        let folderURL = documentsDirectory.appendingPathComponent(folderName)
//
//        if !fileManager.fileExists(atPath: folderURL.path) {
//            do {
//                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
//                print("Folder created at: \(folderURL.path)")
//            } catch {
//                print("Failed to create folder: \(error)")
//            }
//        }
//        return folderURL
//    }
//
//    func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//
//    func listFiles(in folderURL: URL) -> [URL] {
//        do {
//            return try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
//        } catch {
//            print("Error listing files: \(error)")
//            return []
//        }
//    }
//}
//
//
//

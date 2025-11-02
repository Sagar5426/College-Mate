import Foundation
import SwiftData

enum SharedModelContainer {
    // IMPORTANT: Update the App Group ID if it changes in your project settings for both targets
    // App Group ID centralized in SharedAppGroup

    static func make() throws -> ModelContainer {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedAppGroup.id) else {
            throw NSError(domain: "AppGroup", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group URL not found. Enable the same App Group for app and extension."])
        }
        // Use a consistent filename for your SwiftData store
        let storeURL = groupURL.appendingPathComponent("CollegeMate.sqlite")
        let configuration = ModelConfiguration(url: storeURL)
        return try ModelContainer(
            for: Subject.self, Folder.self, FileMetadata.self, // include all SwiftData models used
            configurations: configuration
        )
    }
}

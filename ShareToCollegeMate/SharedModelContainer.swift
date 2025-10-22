import Foundation
import SwiftData

/// Provides a shared ModelContainer configured for the app and its extensions.
/// This replaces the missing symbol used by ShareView.
struct SharedModelContainer {
    /// Attempts to build a ModelContainer using an App Group configuration if available.
    /// Falls back to the default configuration when no App Group identifier is provided.
    static func make() throws -> ModelContainer {
        // Build the schema for the known models used by the app.
        // Ensure these types exist in your project: Subject, Folder, FileMetadata.
        let schema = Schema([
            Subject.self,
            Folder.self,
            FileMetadata.self
        ])

        // Try to read an App Group identifier from Info.plist under key `AppGroupIdentifier`.
        let appGroupID: String? = {
            if let value = Bundle.main.infoDictionary?["AppGroupIdentifier"] as? String,
               !value.isEmpty {
                return value
            }
            return nil
        }()

        if let appGroupID,
           let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            // Place the SwiftData store in the App Group container
            let storeURL = groupURL.appendingPathComponent("Database.store", isDirectory: false)
            let configuration = ModelConfiguration(url: storeURL)
            return try ModelContainer(for: schema, configurations: [configuration])
        } else {
            // Default, non–App Group store (useful for development or when entitlements are missing).
            return try ModelContainer(for: schema)
        }
    }
}

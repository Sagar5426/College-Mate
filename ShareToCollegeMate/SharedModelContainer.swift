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

        // --- THIS IS THE SECOND CRITICAL FIX ---
        // We use the hardcoded App Group ID string, just like in FileDataService.
        // The old logic of reading from Info.plist was the bug.
        let appGroupID: String? = "group.com.sagarjangra.College-Mate"

        if let appGroupID,
           let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            // Place the SwiftData store in the App Group container
            let storeURL = groupURL.appendingPathComponent("Database.store", isDirectory: false)
            let configuration = ModelConfiguration(url: storeURL)
            print("[SharedModelContainer] Using App Group database at: \(storeURL.path)")
            return try ModelContainer(for: schema, configurations: [configuration])
        } else {
            // Default, non–App Group store (useful for development or when entitlements are missing).
            print("[SharedModelContainer] WARNING: App Group not found. Using default non-shared database.")
            return try ModelContainer(for: schema)
        }
    }
}


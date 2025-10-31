import Foundation
import SwiftData

struct SharedModelContainer {
    
    static func make() throws -> ModelContainer {
        
        // 1. Build the complete schema for ALL models
        let schema = Schema([
            Subject.self,
            Folder.self,
            FileMetadata.self,
            Attendance.self,
            AttendanceRecord.self,
            Schedule.self,
            ClassTime.self,
            Note.self
        ])

        // 2. Define App Group ID
        let appGroupID: String? = "group.com.sagarjangra.College-Mate"

        // 3. --- THIS IS THE CORRECT CONFIGURATION ---
        // We define the configuration here. We will create it inside the 'if' block.
        let configuration: ModelConfiguration

        if let appGroupID {
            // We are in the main app or an extension with the App Group
            
            // This is the correct initializer.
            // We provide:
            // 1. The name of the database file (e.g., "Database.store")
            // 2. The group container
            // 3. The CloudKit setting
            //
            // We DO NOT provide a 'url:' or 'schema:'.
            
            configuration = ModelConfiguration(
                "Database.store", // This is the file name for the database
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .automatic
            )
            
            print("[SharedModelContainer] Using App Group with CloudKit sync.")
            
        } else {
            // Fallback (e.g., in simulator without App Groups)
            print("[SharedModelContainer] WARNING: App Group not found. Using default non-shared database.")
            
            configuration = ModelConfiguration(
                "Database.store", // Use the same name
                cloudKitDatabase: .automatic
            )
        }
        
        // 4. Create the ModelContainer
        // We pass the schema (which we defined at the top)
        // and the single configuration we just created.
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

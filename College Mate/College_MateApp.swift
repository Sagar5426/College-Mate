import SwiftUI
import SwiftData

@main
struct College_MateApp: App {
    
    // Create the shared model container.
    // This will now place the database in your App Group.
    private var sharedModelContainer: ModelContainer
    
    init() {
        do {
            sharedModelContainer = try SharedModelContainer.make()
        } catch {
            // If the container fails to load, the app can't function.
            // A fatalError is appropriate here during development.
            fatalError("Failed to create shared model container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        // Use the shared container for the main app.
        .modelContainer(sharedModelContainer)
    }
}


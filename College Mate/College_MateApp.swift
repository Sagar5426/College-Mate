import SwiftUI
import SwiftData
import UserNotifications // <-- ADDED

@main
struct College_MateApp: App {
    
    // Create the shared model container for main app and shared extension.
    private var sharedModelContainer: ModelContainer
    
    init() {
        do {
            sharedModelContainer = try SharedModelContainer.make()
        } catch {
            fatalError("Failed to create shared model container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
        // Use the shared container for the main app.
        .modelContainer(sharedModelContainer)
    }
}

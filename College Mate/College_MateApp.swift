import SwiftUI
import SwiftData
import UserNotifications // <-- Kept from your file

@main
struct College_MateApp: App {
    
    // 1. Brought back the AuthenticationService
    @StateObject private var authService = AuthenticationService()

    // 2. Kept your shared model container setup
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
            // 3. Restored the authentication logic
            if authService.isLoggedIn {
                HomeView()
                    .environmentObject(authService) // Pass auth service
                    .preferredColorScheme(.dark) // Keep your preference
                    .onAppear { // Keep your notification request
                        NotificationManager.shared.requestAuthorization()
                    }
            } else {
                LoginView()
                    .environmentObject(authService) // Pass auth service
                    .preferredColorScheme(.dark) // Keep preference consistent
            }
        }
        // 4. Correctly attach the model container to the Scene
        //    This makes it available to both HomeView and LoginView.
        .modelContainer(sharedModelContainer)
    }
}


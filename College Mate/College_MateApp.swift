import SwiftUI
import SwiftData
import UserNotifications

@main
struct College_MateApp: App {
    
    @StateObject private var authService = AuthenticationService()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
            if authService.isLoggedIn {
                HomeView()
                    .environmentObject(authService)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        NotificationManager.shared.requestAuthorization()
                    }
            } else {
                LoginView()
                    .environmentObject(authService)
                    .preferredColorScheme(.dark)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}


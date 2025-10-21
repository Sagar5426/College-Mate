import SwiftUI

/// An observable class to manage the global authentication state of the user.
///
/// Use this as an @StateObject at the root of your app and pass it down
/// as an @EnvironmentObject to any views that need to know if the user is logged in.
@MainActor
class AuthenticationService: ObservableObject {
    
    /// Published property that indicates if the user is currently authenticated.
    /// When this changes, the UI will update accordingly.
    @Published var isAuthenticated: Bool = false
    
    // In a real app, you would load the user's session from the Keychain here.
    // For now, we'll start with them logged out.
    init() {
        // TODO: Check Keychain for an existing Apple User ID to auto-login.
    }
    
    func login() {
        // This function will be called upon successful sign-in
        self.isAuthenticated = true
    }
    
    func logout() {
        // This function can be called from a settings/profile page
        self.isAuthenticated = false
        // TODO: Clear user identifier from Keychain.
    }
}

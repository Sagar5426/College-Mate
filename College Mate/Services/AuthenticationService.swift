import Foundation
import Combine

class AuthenticationService: ObservableObject {
    
    // A key to safely store and retrieve the login state from UserDefaults.
    private static let isLoggedInKey = "isLoggedIn"
    
    // This property will now read its initial value from device storage.
    @Published var isLoggedIn: Bool {
        didSet {
            // Whenever the value changes, save it to UserDefaults.
            UserDefaults.standard.set(isLoggedIn, forKey: Self.isLoggedInKey)
        }
    }
    
    init() {
        // When the service is created, load the saved login state.
        // If no value is found, it defaults to `false`.
        self.isLoggedIn = UserDefaults.standard.bool(forKey: Self.isLoggedInKey)
    }
    
    func login() {
        isLoggedIn = true
    }
    
    func logout() {
        isLoggedIn = false
    }
}


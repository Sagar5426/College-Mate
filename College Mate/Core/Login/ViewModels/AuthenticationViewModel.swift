import Foundation
import AuthenticationServices
import Combine

class AuthenticationViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
    
    var onLoginSuccess: (() -> Void)?
    var onLoginFailure: ((Error) -> Void)?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // --- THIS IS THE UPDATED PART ---
        // Find the first active UIWindowScene, then get its key window.
        // This is the modern replacement for the deprecated `windows` property.
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            // Fallback to a new window if no scenes are available, though this is rare.
            return UIWindow()
        }
        return window
        // --- END OF UPDATE ---
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // Here you would typically handle the user's credentials.
            // For this app, we just need to know the login was successful.
            
            // The user's unique ID
            let userID = appleIDCredential.user
            
            // User's full name (only received on the FIRST login)
            if let fullName = appleIDCredential.fullName {
                print("User's name: \(fullName.givenName ?? "") \(fullName.familyName ?? "")")
                // You could save this to your app's data if needed.
            }

            // User's email (only received on the FIRST login)
            if let email = appleIDCredential.email {
                print("User's email: \(email)")
                // You could save this to your app's data if needed.
            }
            
            print("Successfully signed in with Apple. User ID: \(userID)")
            
            // Notify the view that login was successful.
            DispatchQueue.main.async {
                self.onLoginSuccess?()
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle errors, such as the user canceling the request.
        print("Sign in with Apple failed with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.onLoginFailure?(error)
        }
    }
}


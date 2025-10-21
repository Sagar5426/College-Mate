//
//  AuthenticationViewModel.swift
//  College Mate
//
//  Created by Sagar Jangra on 21/10/2025.
//

import SwiftUI
import AuthenticationServices

/// The ViewModel that handles the logic for the "Sign in with Apple" flow.
///
/// This class conforms to the necessary delegates to process the authentication request
/// and handle the success or failure callbacks from the AuthenticationServices framework.
class AuthenticationViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    /// A closure that gets called upon a successful login attempt.
    var onLoginSuccess: (() -> Void)?
    
    /// A published property to hold any error messages for the UI.
    @Published var errorMessage: String?
    
    /// Initiates the "Sign in with Apple" authorization flow.
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    /// Handles the result of the authorization request.
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // --- USER SUCCESSFULLY AUTHENTICATED ---
            
            // You can now retrieve the user's unique identifier, name, and email.
            // IMPORTANT: The user's full name and email are only provided the *first time* they sign in.
            // You MUST securely save this information on your server or in the user's Keychain.
            
            let userID = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            
            print("Apple User ID: \(userID)")
            print("User Full Name: \(fullName?.givenName ?? "N/A") \(fullName?.familyName ?? "")")
            print("User Email: \(email ?? "N/A")")
            
            // Here, you would typically save the userID to the Keychain and/or send it to your server.
            
            // Trigger the login success callback.
            DispatchQueue.main.async {
                self.onLoginSuccess?()
            }
            
        } else if let passwordCredential = authorization.credential as? ASPasswordCredential {
            // This is for iCloud Keychain credentials, not Sign in with Apple.
            // You can handle this case if your app also supports traditional logins.
            let username = passwordCredential.user
            _ = passwordCredential.password
            print("Signed in with iCloud Keychain for username: \(username)")
            
        }
    }
    
    /// Handles any errors that occur during the authorization process.
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let authError = error as NSError
        
        // Handle common errors, like the user canceling the request.
        if authError.code == ASAuthorizationError.canceled.rawValue {
            print("User canceled the Sign in with Apple request.")
            return // Don't show an error message for cancellation.
        }
        
        // For other errors, display a message to the user.
        print("Sign in with Apple failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.errorMessage = "Could not sign in with Apple. Please try again."
        }
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
    /// Tells the system which window to present the Sign in with Apple sheet over.
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the main window of the application.
        guard let window = UIApplication.shared.windows.first else {
            fatalError("No window found.")
        }
        return window
    }
}

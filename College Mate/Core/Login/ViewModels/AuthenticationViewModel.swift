import Foundation
import AuthenticationServices
import Combine

class AuthenticationViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
    
    var onLoginSuccess: (() -> Void)?
    var onLoginFailure: ((Error) -> Void)?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            
            let userID = appleIDCredential.user
            if let fullName = appleIDCredential.fullName {
                print("User's name: \(fullName.givenName ?? "") \(fullName.familyName ?? "")")
            }

            if let email = appleIDCredential.email {
                print("User's email: \(email)")
            }
            
            print("Successfully signed in with Apple. User ID: \(userID)")
            
            DispatchQueue.main.async {
                self.onLoginSuccess?()
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.onLoginFailure?(error)
        }
    }
}


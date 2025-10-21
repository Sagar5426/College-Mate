import SwiftUI
import AuthenticationServices

struct LoginView: View {
    
    @StateObject private var viewModel = AuthenticationViewModel()
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        ZStack {
            // Using the same background as the CardDetailView for consistency
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemGray6), Color(.systemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                // MARK: - Header
                VStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    
                    Text("Welcome to College Mate")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Never stress about attendance or lost notes again. We got you. 🤝")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // MARK: - Sign In Button
                SignInWithAppleButton(
                    // Using .continue is best practice for both sign up and sign in
                    .continue,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                // You can handle the credential here if needed,
                                // but our ViewModel delegate handles the main logic.
                                print("Sign in successful. User ID: \(appleIDCredential.user)")
                                authService.login()
                            }
                        case .failure(let error):
                            // The view model's delegate will also catch this,
                            // but you can handle UI-specific error states here.
                            print("Sign in failed: \(error.localizedDescription)")
                        }
                    }
                )
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 55)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

                // MARK: - Footer
                Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                
                Spacer()
                    .frame(height: 50)
            }
        }
        .onAppear {
            // Set up the success handler for the view model
            viewModel.onLoginSuccess = {
                authService.login()
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationService())
}


//
//  AuthView.swift
//  SEEN
//
//  Sign in with Apple authentication view
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    var authService: AuthService
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                    
                    Text("SEEN")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    Text("Accountability that works")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "person.3.fill", text: "Create pods with friends")
                    FeatureRow(icon: "target", text: "Set goals and track progress")
                    FeatureRow(icon: "bell.fill", text: "Get reminded and stay on track")
                    FeatureRow(icon: "flame.fill", text: "Build streaks together")
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Sign in button
                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                    
                    if authService.isLoading {
                        ProgressView()
                            .padding(.top, 8)
                    }
                    
                    if let error = authService.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
                    .frame(height: 40)
            }
        }
    }
    
    private func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken else {
                Task { @MainActor in
                    authService.error = "Failed to get credentials"
                }
                return
            }
            
            let firstName = credential.fullName?.givenName
            let lastName = credential.fullName?.familyName
            
            Task {
                await authService.signInWithApple(
                    identityToken: identityToken,
                    firstName: firstName,
                    lastName: lastName
                )
            }
            
        case .failure(let error):
            // Don't show error for user cancellation
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                Task { @MainActor in
                    authService.error = error.localizedDescription
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    AuthView(authService: AuthService.shared)
}

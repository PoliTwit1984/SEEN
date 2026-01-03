//
//  AuthView.swift
//  SEEN
//
//  Sign in with Apple - Liquid Glass Design
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    var authService: AuthService
    @State private var showFeatures = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and Title
                VStack(spacing: 20) {
                    // Glowing logo
                    ZStack {
                        Circle()
                            .fill(Color.seenGreen.opacity(0.3))
                            .blur(radius: 40)
                            .frame(width: 150, height: 150)
                        
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 100, height: 100)
                            .overlay {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.seenGreen, .seenMint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                    }
                    
                    VStack(spacing: 8) {
                        Text("SEEN")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(6)
                        
                        Text("Accountability that works")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Features in glass cards
                if showFeatures {
                    VStack(spacing: 12) {
                        FeatureRow(icon: "person.3.fill", text: "Create pods with friends", color: .seenGreen)
                        FeatureRow(icon: "target", text: "Set goals and track progress", color: .seenBlue)
                        FeatureRow(icon: "bell.fill", text: "Get reminded and stay on track", color: .seenPurple)
                        FeatureRow(icon: "flame.fill", text: "Build streaks together", color: .orange)
                    }
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer()
                
                // Sign in section
                VStack(spacing: 20) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 56)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    .padding(.horizontal, 32)
                    
                    if authService.isLoading {
                        LoadingView(message: "Signing in...")
                    }
                    
                    if let error = authService.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 32)
                            .multilineTextAlignment(.center)
                            .glassBackground(cornerRadius: 12)
                            .padding(.horizontal, 32)
                    }
                }
                
                Spacer()
                    .frame(height: 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                showFeatures = true
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
    var color: Color = .seenGreen
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassBackground(cornerRadius: 16)
    }
}

#Preview {
    AuthView(authService: AuthService.shared)
}

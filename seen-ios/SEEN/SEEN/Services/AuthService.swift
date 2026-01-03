//
//  AuthService.swift
//  SEEN
//
//  Handles authentication state and Sign in with Apple
//

import Foundation
import AuthenticationServices
import SwiftUI
import Observation

@Observable
@MainActor
final class AuthService {
    static let shared = AuthService()
    
    private(set) var currentUser: User?
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    var error: String?
    
    private init() {
        // Check if we have tokens on init
        checkAuthState()
    }
    
    private func checkAuthState() {
        if let _ = try? KeychainHelper.readString(forKey: "accessToken") {
            isAuthenticated = true
            Task {
                await fetchCurrentUser()
            }
        }
    }
    
    // MARK: - Sign in with Apple
    
    func signInWithApple(
        identityToken: Data,
        firstName: String?,
        lastName: String?
    ) async {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            error = "Failed to decode identity token"
            return
        }
        
        struct SignInRequest: Encodable {
            let identityToken: String
            let firstName: String?
            let lastName: String?
        }
        
        do {
            let request = SignInRequest(
                identityToken: tokenString,
                firstName: firstName,
                lastName: lastName
            )
            
            let response: AuthResponse = try await APIClient.shared.request(
                path: "/auth/apple",
                method: "POST",
                body: request,
                authenticated: false
            )
            
            // Save tokens
            try KeychainHelper.save(response.accessToken, forKey: "accessToken")
            try KeychainHelper.save(response.refreshToken, forKey: "refreshToken")
            
            // Update state
            currentUser = response.user
            isAuthenticated = true
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Fetch Current User
    
    func fetchCurrentUser() async {
        do {
            let user: User = try await APIClient.shared.request(path: "/users/me")
            currentUser = user
            isAuthenticated = true
        } catch {
            // If unauthorized, clear auth state
            if case APIError.unauthorized = error {
                logout()
            }
        }
    }
    
    // MARK: - Logout
    
    func logout() {
        // Call logout endpoint (fire and forget)
        Task {
            if let refreshToken = try? KeychainHelper.readString(forKey: "refreshToken") {
                struct LogoutRequest: Encodable {
                    let refreshToken: String
                }
                let _ = try? await APIClient.shared.request(
                    path: "/auth/logout",
                    method: "POST",
                    body: LogoutRequest(refreshToken: refreshToken),
                    authenticated: false
                ) as EmptyResponse
            }
        }
        
        // Clear local state
        KeychainHelper.deleteAll()
        currentUser = nil
        isAuthenticated = false
    }
}

// For endpoints that return empty data
struct EmptyResponse: Codable {
    let message: String?
}

// MARK: - Sign in with Apple Coordinator

class SignInWithAppleCoordinator: NSObject, ASAuthorizationControllerDelegate {
    typealias SignInResult = (identityToken: Data, firstName: String?, lastName: String?)
    private var continuation: CheckedContinuation<SignInResult, Error>?
    
    func signIn() async throws -> SignInResult {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SignInResult, Error>) in
            self.continuation = continuation
            
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken else {
            continuation?.resume(throwing: APIError.serverError("Missing identity token"))
            continuation = nil
            return
        }
        
        let firstName = credential.fullName?.givenName
        let lastName = credential.fullName?.familyName
        
        continuation?.resume(returning: (identityToken, firstName, lastName))
        continuation = nil
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

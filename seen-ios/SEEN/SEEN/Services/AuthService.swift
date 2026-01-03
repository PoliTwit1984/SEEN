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
import UIKit

// MARK: - Avatar Upload Models (must be outside @MainActor class)

struct AvatarPresignResponse: Codable, Sendable {
    let uploadUrl: String
    let publicUrl: String
    let key: String
    let configured: Bool
}

struct AvatarPresignRequest: Codable, Sendable {
    let fileType: String
}

struct UpdateProfileRequest: Codable, Sendable {
    let name: String?
    let timezone: String?
    let avatarUrl: String?
}

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
    
    // MARK: - Fetch User Stats
    
    func fetchUserStats() async -> UserStats? {
        do {
            let stats: UserStats = try await APIClient.shared.request(path: "/users/me/stats")
            return stats
        } catch {
            print("Failed to fetch user stats: \(error)")
            return nil
        }
    }
    
    // MARK: - Update Profile
    
    func updateProfile(name: String? = nil, timezone: String? = nil, avatarUrl: String? = nil) async throws {
        let request = UpdateProfileRequest(name: name, timezone: timezone, avatarUrl: avatarUrl)
        let user: User = try await APIClient.shared.request(
            path: "/users/me",
            method: "PATCH",
            body: request
        )
        currentUser = user
    }
    
    // MARK: - Upload Avatar
    
    func uploadAvatar(image: UIImage) async throws -> String {
        // 1. Get presigned URL
        let presignRequest = AvatarPresignRequest(fileType: "jpg")
        
        let presignResponse: AvatarPresignResponse
        do {
            presignResponse = try await APIClient.shared.request(
                path: "/uploads/avatar/presign",
                method: "POST",
                body: presignRequest
            )
            print("✅ Presign response: configured=\(presignResponse.configured)")
        } catch {
            print("❌ Presign error: \(error)")
            throw error
        }
        
        // 2. If not configured, just update profile with mock URL
        if !presignResponse.configured {
            print("⚠️ Storage not configured, using mock URL")
            try await updateProfile(avatarUrl: presignResponse.publicUrl)
            return presignResponse.publicUrl
        }
        
        // 3. Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.serverError("Failed to compress image")
        }
        
        // 4. Upload to R2
        guard let uploadURL = URL(string: presignResponse.uploadUrl) else {
            throw APIError.serverError("Invalid upload URL")
        }
        
        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = imageData
        
        let (_, response) = try await URLSession.shared.data(for: uploadRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Failed to upload image")
        }
        
        // 5. Update user profile with new avatar URL
        print("✅ Upload complete, updating profile with URL: \(presignResponse.publicUrl)")
        do {
            try await updateProfile(avatarUrl: presignResponse.publicUrl)
            print("✅ Profile updated successfully")
        } catch {
            print("❌ Profile update error: \(error)")
            throw error
        }
        
        return presignResponse.publicUrl
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

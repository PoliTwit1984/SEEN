//
//  User.swift
//  SEEN
//
//  User model matching backend response
//

import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let name: String
    let avatarUrl: String?
    let timezone: String
    let createdAt: String?
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User
    let isNewUser: Bool
}

struct TokenRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
}

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: APIErrorResponse?
}

struct APIErrorResponse: Codable {
    let code: String
    let message: String
}

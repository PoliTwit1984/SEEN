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

struct UserStats: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let totalCheckIns: Int
    let activeGoals: Int
    let podsCount: Int
    let memberSince: String?
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

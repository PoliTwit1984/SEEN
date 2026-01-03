//
//  APIClient.swift
//  SEEN
//
//  Handles all API requests with automatic token refresh
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Please sign in again"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

actor APIClient {
    static let shared = APIClient()
    
    private let baseURL = Config.apiBaseURL
    private var isRefreshing = false
    private var refreshContinuations: [CheckedContinuation<Void, Error>] = []
    
    private init() {}
    
    // MARK: - Token Management
    
    private func getAccessToken() -> String? {
        try? KeychainHelper.readString(forKey: "accessToken")
    }
    
    private func getRefreshToken() -> String? {
        try? KeychainHelper.readString(forKey: "refreshToken")
    }
    
    private func saveTokens(access: String, refresh: String) throws {
        try KeychainHelper.save(access, forKey: "accessToken")
        try KeychainHelper.save(refresh, forKey: "refreshToken")
    }
    
    // MARK: - Request Building
    
    private func buildRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        authenticated: Bool = true
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if authenticated, let token = getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - Token Refresh
    
    private func refreshTokens() async throws {
        guard let refreshToken = getRefreshToken() else {
            throw APIError.unauthorized
        }
        
        let body = try JSONEncoder().encode(["refreshToken": refreshToken])
        var request = try buildRequest(path: "/auth/refresh", method: "POST", body: body, authenticated: false)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        
        if httpResponse.statusCode == 401 {
            KeychainHelper.deleteAll()
            throw APIError.unauthorized
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse<TokenRefreshResponse>.self, from: data)
        
        if let tokens = apiResponse.data {
            try saveTokens(access: tokens.accessToken, refresh: tokens.refreshToken)
        } else if let error = apiResponse.error {
            throw APIError.serverError(error.message)
        }
    }
    
    private func waitForRefreshOrStart() async throws {
        if isRefreshing {
            // Wait for ongoing refresh
            try await withCheckedThrowingContinuation { continuation in
                refreshContinuations.append(continuation)
            }
        } else {
            // Start refresh
            isRefreshing = true
            do {
                try await refreshTokens()
                isRefreshing = false
                // Resume all waiters
                for continuation in refreshContinuations {
                    continuation.resume()
                }
                refreshContinuations.removeAll()
            } catch {
                isRefreshing = false
                // Fail all waiters
                for continuation in refreshContinuations {
                    continuation.resume(throwing: error)
                }
                refreshContinuations.removeAll()
                throw error
            }
        }
    }
    
    // MARK: - Public API
    
    func request<T: Codable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        let bodyData = try body.map { try JSONEncoder().encode($0) }
        
        // First attempt
        do {
            return try await performRequest(path: path, method: method, body: bodyData, authenticated: authenticated)
        } catch APIError.unauthorized where authenticated {
            // Try to refresh and retry once
            try await waitForRefreshOrStart()
            return try await performRequest(path: path, method: method, body: bodyData, authenticated: authenticated)
        }
    }
    
    private func performRequest<T: Codable>(
        path: String,
        method: String,
        body: Data?,
        authenticated: Bool
    ) async throws -> T {
        let request = try buildRequest(path: path, method: method, body: body, authenticated: authenticated)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        do {
            let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
            
            if apiResponse.success, let responseData = apiResponse.data {
                return responseData
            } else if let error = apiResponse.error {
                throw APIError.serverError(error.message)
            } else {
                throw APIError.noData
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

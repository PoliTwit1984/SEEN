//
//  FeedService.swift
//  SEEN
//
//  Handles feed and interaction API calls
//

import Foundation

actor FeedService {
    static let shared = FeedService()
    
    private init() {}
    
    // MARK: - Get Feed
    
    func getFeed(limit: Int = 20, offset: Int = 0) async throws -> [FeedItem] {
        return try await APIClient.shared.request(
            path: "/feed?limit=\(limit)&offset=\(offset)"
        )
    }
    
    func getPodFeed(podId: String, limit: Int = 20, offset: Int = 0) async throws -> [FeedItem] {
        return try await APIClient.shared.request(
            path: "/feed/pod/\(podId)?limit=\(limit)&offset=\(offset)"
        )
    }
    
    // MARK: - Interactions
    
    func addInteraction(checkInId: String, type: InteractionType) async throws -> InteractionResponse {
        let request = CreateInteractionRequest(checkInId: checkInId, type: type.rawValue)
        return try await APIClient.shared.request(
            path: "/interactions",
            method: "POST",
            body: request
        )
    }
    
    func removeInteraction(checkInId: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.request(
            path: "/interactions/\(checkInId)",
            method: "DELETE"
        )
    }
}

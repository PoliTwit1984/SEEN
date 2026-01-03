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
    
    // MARK: - Unified Feed (all pods)
    
    func getUnifiedFeed(cursor: String? = nil, limit: Int = 20) async throws -> UnifiedFeedResponse {
        var path = "/feed/unified?limit=\(limit)"
        if let cursor = cursor {
            path += "&cursor=\(cursor)"
        }
        return try await APIClient.shared.request(path: path)
    }
    
    // MARK: - Get Pod Story Items
    
    /// Get feed items for a pod formatted for story view (most recent first, with photos prioritized)
    func getPodStoryItems(podId: String, limit: Int = 30) async throws -> [FeedItem] {
        // Uses the same endpoint but fetches more items for the story experience
        let items: [FeedItem] = try await APIClient.shared.request(
            path: "/feed/pod/\(podId)?limit=\(limit)&offset=0"
        )
        
        // Prioritize items with photos for better story experience
        let sortedItems = items.sorted { item1, item2 in
            // Items with photos first
            let hasPhoto1 = item1.checkIn.proofUrl != nil && !item1.checkIn.proofUrl!.isEmpty
            let hasPhoto2 = item2.checkIn.proofUrl != nil && !item2.checkIn.proofUrl!.isEmpty
            
            if hasPhoto1 && !hasPhoto2 {
                return true
            } else if !hasPhoto1 && hasPhoto2 {
                return false
            }
            
            // Then by date (most recent first)
            return item1.createdAt > item2.createdAt
        }
        
        return sortedItems
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

    // MARK: - Feed Item Reactions

    /// Add or update a reaction on a feed item (check-in or post)
    func addReaction(itemType: String, itemId: String, type: InteractionType) async throws -> ReactionResponse {
        let request = ["type": type.rawValue]
        return try await APIClient.shared.request(
            path: "/feed/items/\(itemType)/\(itemId)/react",
            method: "POST",
            body: request
        )
    }

    /// Remove reaction from a feed item
    func removeReaction(itemType: String, itemId: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.request(
            path: "/feed/items/\(itemType)/\(itemId)/react",
            method: "DELETE"
        )
    }

    // MARK: - Feed Item Comments

    /// Get comments for a feed item
    func getComments(itemType: String, itemId: String, cursor: String? = nil, limit: Int = 20) async throws -> FeedCommentsResponse {
        var path = "/feed/items/\(itemType)/\(itemId)/comments?limit=\(limit)"
        if let cursor = cursor {
            path += "&cursor=\(cursor)"
        }
        return try await APIClient.shared.request(path: path)
    }

    /// Add a comment to a feed item
    func addComment(itemType: String, itemId: String, content: String?, mediaUrl: String? = nil, mediaType: MediaType? = nil) async throws -> FeedComment {
        let request = CreateFeedCommentRequest(
            content: content,
            mediaUrl: mediaUrl,
            mediaType: mediaType?.rawValue
        )
        return try await APIClient.shared.request(
            path: "/feed/items/\(itemType)/\(itemId)/comments",
            method: "POST",
            body: request
        )
    }

    /// Delete a comment
    func deleteComment(commentId: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.request(
            path: "/feed/comments/\(commentId)",
            method: "DELETE"
        )
    }
}

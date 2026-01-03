//
//  Feed.swift
//  SEEN
//
//  Feed and Interaction models
//

import Foundation

enum InteractionType: String, Codable, CaseIterable {
    case HIGH_FIVE
    case FIRE
    case CLAP
    case HEART
    
    var emoji: String {
        switch self {
        case .HIGH_FIVE: return "🙌"
        case .FIRE: return "🔥"
        case .CLAP: return "👏"
        case .HEART: return "❤️"
        }
    }
}

struct FeedItem: Codable, Identifiable {
    let id: String
    let type: String
    let user: FeedUser
    let goal: FeedGoal
    let pod: FeedPod?
    let checkIn: FeedCheckIn
    let interactions: [FeedInteraction]
    let interactionCount: Int
    let hasInteracted: Bool
    let myInteractionType: InteractionType?
    let createdAt: String
}

struct FeedUser: Codable {
    let id: String
    let name: String
    let avatarUrl: String?
}

struct FeedGoal: Codable {
    let id: String
    let title: String
}

struct FeedPod: Codable {
    let id: String
    let name: String
}

struct FeedCheckIn: Codable {
    let date: String
    let status: String
    let proofUrl: String?
    let comment: String?
}

struct FeedInteraction: Codable, Identifiable {
    let id: String
    let type: InteractionType
    let userId: String
    let userName: String
}

// MARK: - Feed Comment

struct FeedComment: Codable, Identifiable {
    let id: String
    let content: String?
    let mediaUrl: String?
    let mediaType: MediaType?
    let author: FeedUser
    let createdAt: String

    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }

    var hasMedia: Bool {
        mediaUrl != nil && !mediaUrl!.isEmpty
    }

    var relativeTime: String {
        guard let date = createdAtDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct FeedCommentsResponse: Codable {
    let comments: [FeedComment]
    let nextCursor: String?
}

// MARK: - Request models

struct CreateInteractionRequest: Encodable {
    let checkInId: String
    let type: String
}

struct CreateFeedCommentRequest: Encodable {
    let content: String?
    let mediaUrl: String?
    let mediaType: String?
}

struct InteractionResponse: Codable {
    let id: String
    let checkInId: String
    let type: InteractionType
    let user: FeedUser
    let createdAt: String
}

struct ReactionResponse: Codable {
    let id: String
    let type: InteractionType
    let createdAt: String
}

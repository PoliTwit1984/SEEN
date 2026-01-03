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

// Request models
struct CreateInteractionRequest: Encodable {
    let checkInId: String
    let type: String
}

struct InteractionResponse: Codable {
    let id: String
    let checkInId: String
    let type: InteractionType
    let user: FeedUser
    let createdAt: String
}

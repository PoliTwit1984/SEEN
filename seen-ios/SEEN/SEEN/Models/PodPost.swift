import Foundation

// MARK: - Post Types

enum PostType: String, Codable, CaseIterable {
    case ENCOURAGEMENT
    case NUDGE
    case CELEBRATION
    case CHECK_IN

    var displayName: String {
        switch self {
        case .ENCOURAGEMENT: return "Encouragement"
        case .NUDGE: return "Nudge"
        case .CELEBRATION: return "Celebration"
        case .CHECK_IN: return "Check-in"
        }
    }

    var emoji: String {
        switch self {
        case .ENCOURAGEMENT: return "💪"
        case .NUDGE: return "👊"
        case .CELEBRATION: return "🎉"
        case .CHECK_IN: return "✅"
        }
    }
}

enum MediaType: String, Codable {
    case PHOTO
    case VIDEO
    case AUDIO
    
    var emoji: String {
        switch self {
        case .PHOTO: return "📸"
        case .VIDEO: return "🎥"
        case .AUDIO: return "🎤"
        }
    }
}

// MARK: - Pod Post

struct PodPost: Codable, Identifiable {
    let id: String
    let type: PostType
    let content: String?
    let mediaUrl: String?
    let mediaType: MediaType?
    let author: PostAuthor
    let target: PostAuthor?
    let podId: String?
    let podName: String?
    let goalTitle: String?
    let createdAt: String

    // Goal metadata (for CHECK_IN type)
    let goalDescription: String?
    let goalFrequency: String?
    let currentStreak: Int?
    let completedAt: String?

    // Interaction data
    let reactionCount: Int
    let commentCount: Int
    let myReaction: InteractionType?
    let topReactions: [InteractionType]

    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }

    var hasMedia: Bool {
        mediaUrl != nil && !mediaUrl!.isEmpty
    }

    var formattedCompletedAt: String? {
        guard let completedAt = completedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: completedAt) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: completedAt) else { return nil }
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            return timeFormatter.string(from: date)
        }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: date)
    }
}

struct PostAuthor: Codable, Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
}

// MARK: - Goal Comment

struct GoalComment: Codable, Identifiable {
    let id: String
    let content: String?
    let mediaUrl: String?
    let mediaType: MediaType?
    let author: PostAuthor
    let createdAt: String
    
    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }
    
    var hasMedia: Bool {
        mediaUrl != nil && !mediaUrl!.isEmpty
    }
}

// MARK: - Request Models

struct CreatePostRequest: Codable {
    let type: PostType
    let content: String?
    let mediaUrl: String?
    let mediaType: MediaType?
    let targetUserId: String?
}

struct CreateCommentRequest: Codable {
    let content: String?
    let mediaUrl: String?
    let mediaType: MediaType?
}

// MARK: - Response Wrappers

struct PostsResponse: Codable {
    let posts: [PodPost]
    let nextCursor: String?
}

struct CommentsResponse: Codable {
    let comments: [GoalComment]
    let nextCursor: String?
}

// MARK: - Unified Feed Response

struct UnifiedFeedResponse: Codable {
    let items: [PodPost]
    let nextCursor: String?
}

import Foundation

// MARK: - Post Types

enum PostType: String, Codable, CaseIterable {
    case ENCOURAGEMENT
    case NUDGE
    case CELEBRATION
    
    var displayName: String {
        switch self {
        case .ENCOURAGEMENT: return "Encouragement"
        case .NUDGE: return "Nudge"
        case .CELEBRATION: return "Celebration"
        }
    }
    
    var emoji: String {
        switch self {
        case .ENCOURAGEMENT: return "💪"
        case .NUDGE: return "👊"
        case .CELEBRATION: return "🎉"
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
    let createdAt: String
    
    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }
    
    var hasMedia: Bool {
        mediaUrl != nil && !mediaUrl!.isEmpty
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

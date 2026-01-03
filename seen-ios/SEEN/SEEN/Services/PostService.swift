import Foundation

@Observable
final class PostService {
    static let shared = PostService()
    
    private init() {}
    
    // MARK: - Pod Dashboard
    
    func getPodDashboard(podId: String) async throws -> PodDashboard {
        return try await APIClient.shared.request(path: "/pods/\(podId)/dashboard")
    }
    
    func getMemberStatuses(podId: String) async throws -> [MemberStatusWithGoals] {
        return try await APIClient.shared.request(path: "/pods/\(podId)/members/status")
    }
    
    // MARK: - Pod Posts
    
    func getPodPosts(podId: String, cursor: String? = nil) async throws -> PostsResponse {
        var path = "/pods/\(podId)/posts"
        if let cursor = cursor {
            path += "?cursor=\(cursor)"
        }
        return try await APIClient.shared.request(path: path)
    }
    
    func createPost(
        podId: String,
        type: PostType,
        content: String?,
        mediaUrl: String?,
        mediaType: MediaType?,
        targetUserId: String? = nil
    ) async throws -> PodPost {
        let request = CreatePostRequest(
            type: type,
            content: content,
            mediaUrl: mediaUrl,
            mediaType: mediaType,
            targetUserId: targetUserId
        )
        return try await APIClient.shared.request(
            path: "/pods/\(podId)/posts",
            method: "POST",
            body: request
        )
    }
    
    func sendNudge(podId: String, targetUserId: String, content: String? = nil) async throws {
        struct NudgeRequest: Codable {
            let content: String?
        }
        let _: EmptyResponse = try await APIClient.shared.request(
            path: "/pods/\(podId)/nudge/\(targetUserId)",
            method: "POST",
            body: NudgeRequest(content: content)
        )
    }
    
    // MARK: - Goal Comments
    
    func getGoalComments(goalId: String, cursor: String? = nil) async throws -> CommentsResponse {
        var path = "/goals/\(goalId)/comments"
        if let cursor = cursor {
            path += "?cursor=\(cursor)"
        }
        return try await APIClient.shared.request(path: path)
    }
    
    func addGoalComment(
        goalId: String,
        content: String?,
        mediaUrl: String?,
        mediaType: MediaType?
    ) async throws -> GoalComment {
        let request = CreateCommentRequest(
            content: content,
            mediaUrl: mediaUrl,
            mediaType: mediaType
        )
        return try await APIClient.shared.request(
            path: "/goals/\(goalId)/comments",
            method: "POST",
            body: request
        )
    }
    
    func deleteGoalComment(goalId: String, commentId: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.request(
            path: "/goals/\(goalId)/comments/\(commentId)",
            method: "DELETE"
        )
    }
}

import Foundation

// MARK: - Pod Dashboard Response

struct PodDashboard: Codable {
    let pod: PodInfo
    let health: PodHealth
    let memberStatuses: [MemberStatus]
    let needsEncouragement: [NeedsEncouragementMember]
}

struct PodInfo: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let stakes: String?
    let inviteCode: String
}

struct PodHealth: Codable {
    let totalMembers: Int
    let membersWithGoals: Int
    let completedToday: Int
    let pendingToday: Int
    let missedToday: Int
    
    var completionRate: Double {
        guard membersWithGoals > 0 else { return 0 }
        return Double(completedToday) / Double(membersWithGoals)
    }
}

// MARK: - Member Status

enum MemberTodayStatus: String, Codable {
    case completed
    case pending
    case missed
    case no_goals
    
    var emoji: String {
        switch self {
        case .completed: return "✅"
        case .pending: return "⏳"
        case .missed: return "❌"
        case .no_goals: return "🎯"
        }
    }
    
    var displayText: String {
        switch self {
        case .completed: return "All done!"
        case .pending: return "Pending"
        case .missed: return "Missed"
        case .no_goals: return "No goals"
        }
    }
}

struct MemberStatus: Codable, Identifiable {
    let userId: String
    let name: String
    let avatarUrl: String?
    let todayStatus: MemberTodayStatus
    let currentStreak: Int
    let totalGoals: Int?
    let completedToday: Int?
    let pendingToday: Int?
    let isCurrentUser: Bool?
    
    var id: String { userId }
}

struct NeedsEncouragementMember: Codable, Identifiable {
    let userId: String
    let name: String
    let avatarUrl: String?
    let status: MemberTodayStatus
    let pendingGoals: Int
    
    var id: String { userId }
}

// MARK: - Member Status with Goals (for detail sheet)

struct MemberStatusWithGoals: Codable, Identifiable {
    let userId: String
    let name: String
    let avatarUrl: String?
    let todayStatus: MemberTodayStatus
    let currentStreak: Int
    let pendingGoals: [PendingGoal]
    
    var id: String { userId }
}

struct PendingGoal: Codable, Identifiable {
    let id: String
    let title: String
}

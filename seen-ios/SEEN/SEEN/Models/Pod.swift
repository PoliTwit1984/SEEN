//
//  Pod.swift
//  SEEN
//
//  Pod and PodMember models
//

import Foundation

struct Pod: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let stakes: String?
    let memberCount: Int?
    let maxMembers: Int
    let inviteCode: String?
    let role: MemberRole?
    let joinedAt: String?
    let createdAt: String
    let members: [PodMember]?
}

struct PodMember: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let avatarUrl: String?
    let role: MemberRole
    let joinedAt: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PodMember, rhs: PodMember) -> Bool {
        lhs.id == rhs.id
    }
}

enum MemberRole: String, Codable {
    case OWNER
    case MEMBER
}

// Request models
struct CreatePodRequest: Encodable {
    let name: String
    let description: String?
    let stakes: String?
    let maxMembers: Int?
}

struct JoinPodRequest: Encodable {
    let inviteCode: String
}

// List response (simplified pod info)
struct PodListItem: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let stakes: String?
    let memberCount: Int
    let maxMembers: Int
    let role: MemberRole
    let joinedAt: String
    let createdAt: String
    // Additional fields for UI display
    let memberAvatars: [String]?
    let latestPhotoUrl: String?
    let checkedInCount: Int?
    let totalMembersWithGoals: Int?
    
    init(id: String, name: String, description: String?, stakes: String?, memberCount: Int, maxMembers: Int, role: MemberRole, joinedAt: String, createdAt: String, memberAvatars: [String]? = nil, latestPhotoUrl: String? = nil, checkedInCount: Int? = nil, totalMembersWithGoals: Int? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.stakes = stakes
        self.memberCount = memberCount
        self.maxMembers = maxMembers
        self.role = role
        self.joinedAt = joinedAt
        self.createdAt = createdAt
        self.memberAvatars = memberAvatars
        self.latestPhotoUrl = latestPhotoUrl
        self.checkedInCount = checkedInCount
        self.totalMembersWithGoals = totalMembersWithGoals
    }
    
    // Health status text
    var healthStatus: String {
        guard let checked = checkedInCount, let total = totalMembersWithGoals, total > 0 else {
            return "\(memberCount) members"
        }
        return "\(checked)/\(total) checked in today"
    }
}

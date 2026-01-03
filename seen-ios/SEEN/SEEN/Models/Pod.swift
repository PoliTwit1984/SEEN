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

struct PodMember: Codable, Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
    let role: MemberRole
    let joinedAt: String
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
}

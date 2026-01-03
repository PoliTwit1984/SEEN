//
//  PodStatus.swift
//  SEEN
//
//  Pod with activity status for visual feed
//

import Foundation

struct PodWithStatus: Codable, Identifiable {
    let id: String
    let name: String
    let memberCount: Int
    let maxMembers: Int
    let hasNewActivity: Bool
    let latestCheckInPhoto: String?
    let unreadCount: Int
    let myPendingGoals: Int
}

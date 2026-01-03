//
//  Goal.swift
//  SEEN
//
//  Goal and CheckIn models
//

import Foundation

enum FrequencyType: String, Codable, CaseIterable {
    case DAILY
    case WEEKLY
    case SPECIFIC_DAYS
    
    var displayName: String {
        switch self {
        case .DAILY: return "Daily"
        case .WEEKLY: return "Weekly"
        case .SPECIFIC_DAYS: return "Specific Days"
        }
    }
}

enum CheckInStatus: String, Codable {
    case COMPLETED
    case MISSED
    case SKIPPED
}

struct Goal: Codable, Identifiable {
    let id: String
    let podId: String?
    let podName: String?
    let userId: String?
    let userName: String?
    let userAvatarUrl: String?
    let title: String
    let description: String?
    let frequencyType: FrequencyType?
    let frequencyDays: [Int]?
    let reminderTime: String?
    let deadlineTime: String?
    let timezone: String?
    let requiresProof: Bool?
    let startDate: String?
    let endDate: String?
    let currentStreak: Int
    let longestStreak: Int
    let totalCheckIns: Int?
    let completedCheckIns: Int?
    let isArchived: Bool?
    let createdAt: String
    let checkIns: [CheckIn]?
    
    // Computed properties with defaults
    var displayFrequency: String {
        frequencyType?.displayName ?? "Daily"
    }
    
    var needsProof: Bool {
        requiresProof ?? false
    }
}

struct CheckIn: Codable, Identifiable {
    let id: String
    let date: String
    let status: CheckInStatus
    let proofUrl: String?
    let comment: String?
    let createdAt: String
}

// Request models
struct CreateGoalRequest: Encodable {
    let podId: String
    let title: String
    let description: String?
    let frequencyType: String
    let frequencyDays: [Int]?
    let reminderTime: String?
    let deadlineTime: String?
    let timezone: String?
    let requiresProof: Bool
    let startDate: String?
    let endDate: String?
}

struct UpdateGoalRequest: Encodable {
    let title: String?
    let description: String?
    let reminderTime: String?
    let deadlineTime: String?
    let requiresProof: Bool?
    let endDate: String?
    let isArchived: Bool?
}

// Helper for day names
enum Weekday: Int, CaseIterable {
    case sunday = 0
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
    
    var initial: String {
        String(shortName.prefix(1))
    }
}

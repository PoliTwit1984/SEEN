//
//  GoalService.swift
//  SEEN
//
//  Handles goal-related API calls
//

import Foundation

actor GoalService {
    static let shared = GoalService()
    
    private init() {}
    
    // MARK: - List Goals
    
    func getMyGoals(podId: String? = nil) async throws -> [Goal] {
        var path = "/goals"
        if let podId = podId {
            path += "?podId=\(podId)"
        }
        return try await APIClient.shared.request(path: path)
    }
    
    func getPodGoals(podId: String) async throws -> [Goal] {
        return try await APIClient.shared.request(path: "/goals/pod/\(podId)")
    }
    
    // MARK: - Create Goal
    
    func createGoal(
        podId: String,
        title: String,
        description: String?,
        frequencyType: FrequencyType,
        frequencyDays: [Int]?,
        reminderTime: String?,
        deadlineTime: String?,
        requiresProof: Bool
    ) async throws -> Goal {
        let request = CreateGoalRequest(
            podId: podId,
            title: title,
            description: description,
            frequencyType: frequencyType.rawValue,
            frequencyDays: frequencyDays,
            reminderTime: reminderTime,
            deadlineTime: deadlineTime,
            timezone: TimeZone.current.identifier,
            requiresProof: requiresProof,
            startDate: ISO8601DateFormatter().string(from: Date()),
            endDate: nil
        )
        return try await APIClient.shared.request(
            path: "/goals",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Get Goal Details
    
    func getGoal(id: String) async throws -> Goal {
        return try await APIClient.shared.request(path: "/goals/\(id)")
    }
    
    // MARK: - Update Goal
    
    func updateGoal(id: String, updates: UpdateGoalRequest) async throws -> Goal {
        return try await APIClient.shared.request(
            path: "/goals/\(id)",
            method: "PATCH",
            body: updates
        )
    }
    
    // MARK: - Archive Goal
    
    func archiveGoal(id: String) async throws -> Goal {
        let updates = UpdateGoalRequest(
            title: nil,
            description: nil,
            reminderTime: nil,
            deadlineTime: nil,
            requiresProof: nil,
            endDate: nil,
            isArchived: true
        )
        return try await updateGoal(id: id, updates: updates)
    }
}

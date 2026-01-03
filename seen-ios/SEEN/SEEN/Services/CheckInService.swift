//
//  CheckInService.swift
//  SEEN
//
//  Handles check-in API calls
//

import Foundation

struct CheckInResponse: Codable {
    let id: String
    let goalId: String
    let date: String
    let status: CheckInStatus
    let comment: String?
    let proofUrl: String?
    let createdAt: String
    let currentStreak: Int
    let longestStreak: Int
}

struct TodayCheckInResponse: Codable {
    let checkedIn: Bool
    let checkIn: TodayCheckIn?
}

struct TodayCheckIn: Codable {
    let id: String
    let status: CheckInStatus
    let createdAt: String
}

struct CreateCheckInRequest: Encodable {
    let goalId: String
    let status: String
    let comment: String?
    let proofUrl: String?
    let clientTimestamp: String?
}

actor CheckInService {
    static let shared = CheckInService()
    
    private init() {}
    
    // MARK: - Create Check-in
    
    func checkIn(
        goalId: String,
        status: CheckInStatus = .COMPLETED,
        comment: String? = nil,
        proofUrl: String? = nil
    ) async throws -> CheckInResponse {
        let request = CreateCheckInRequest(
            goalId: goalId,
            status: status.rawValue,
            comment: comment,
            proofUrl: proofUrl,
            clientTimestamp: ISO8601DateFormatter().string(from: Date())
        )
        return try await APIClient.shared.request(
            path: "/checkins",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Get Check-ins
    
    func getCheckIns(goalId: String, limit: Int = 30) async throws -> [CheckIn] {
        return try await APIClient.shared.request(
            path: "/checkins/\(goalId)?limit=\(limit)"
        )
    }
    
    // MARK: - Check Today Status
    
    func getTodayStatus(goalId: String) async throws -> TodayCheckInResponse {
        return try await APIClient.shared.request(
            path: "/checkins/today/\(goalId)"
        )
    }
}

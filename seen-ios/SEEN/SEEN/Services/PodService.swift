//
//  PodService.swift
//  SEEN
//
//  Handles pod-related API calls
//

import Foundation

actor PodService {
    static let shared = PodService()
    
    private init() {}
    
    // MARK: - List Pods
    
    func getMyPods() async throws -> [PodListItem] {
        return try await APIClient.shared.request(path: "/pods")
    }
    
    // MARK: - Create Pod
    
    func createPod(name: String, description: String?, stakes: String?) async throws -> Pod {
        let request = CreatePodRequest(
            name: name,
            description: description,
            stakes: stakes,
            maxMembers: nil
        )
        return try await APIClient.shared.request(
            path: "/pods",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Get Pod Details
    
    func getPod(id: String) async throws -> Pod {
        return try await APIClient.shared.request(path: "/pods/\(id)")
    }
    
    // MARK: - Join Pod
    
    func joinPod(inviteCode: String) async throws -> Pod {
        let request = JoinPodRequest(inviteCode: inviteCode)
        return try await APIClient.shared.request(
            path: "/pods/join",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Leave Pod
    
    func leavePod(podId: String, userId: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.request(
            path: "/pods/\(podId)/members/\(userId)",
            method: "DELETE"
        )
    }
}

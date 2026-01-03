//
//  PhotoUploadService.swift
//  SEEN
//
//  Handles photo uploads to cloud storage
//

import Foundation
import UIKit

actor PhotoUploadService {
    static let shared = PhotoUploadService()
    
    private init() {}
    
    // MARK: - Models
    
    struct PresignedURLResponse: Codable {
        let uploadUrl: String
        let publicUrl: String
        let key: String
        let configured: Bool
    }
    
    struct PresignedURLRequest: Encodable {
        let goalId: String
        let fileType: String
    }
    
    // MARK: - Get Presigned URL
    
    func getPresignedURL(goalId: String, fileType: String = "jpg") async throws -> PresignedURLResponse {
        let request = PresignedURLRequest(goalId: goalId, fileType: fileType)
        return try await APIClient.shared.request(
            path: "/uploads/presign",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Upload Photo
    
    func uploadPhoto(image: UIImage, goalId: String) async throws -> String {
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.compressionFailed
        }
        
        // Get presigned URL
        let presigned = try await getPresignedURL(goalId: goalId, fileType: "jpg")
        
        // If storage not configured, return mock URL
        if !presigned.configured {
            print("⚠️ Storage not configured - returning mock URL")
            return presigned.publicUrl
        }
        
        // Upload to presigned URL
        guard let uploadURL = URL(string: presigned.uploadUrl) else {
            throw UploadError.invalidURL
        }
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw UploadError.uploadFailed(statusCode: httpResponse.statusCode)
        }
        
        return presigned.publicUrl
    }
}

// MARK: - Errors

enum UploadError: LocalizedError {
    case compressionFailed
    case invalidURL
    case invalidResponse
    case uploadFailed(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .invalidURL:
            return "Invalid upload URL"
        case .invalidResponse:
            return "Invalid server response"
        case .uploadFailed(let code):
            return "Upload failed with status \(code)"
        }
    }
}

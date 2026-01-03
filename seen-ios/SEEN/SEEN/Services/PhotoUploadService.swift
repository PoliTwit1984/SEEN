//
//  PhotoUploadService.swift
//  SEEN
//
//  Handles media uploads (photos, videos, audio) to cloud storage
//

import Foundation
import UIKit
import AVFoundation

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
        return try await uploadData(imageData, to: presigned, contentType: "image/jpeg")
    }
    
    // MARK: - Upload Video
    
    func uploadVideo(url: URL, goalId: String) async throws -> String {
        // Read video data
        let videoData = try Data(contentsOf: url)
        
        // Get presigned URL for mp4
        let presigned = try await getPresignedURL(goalId: goalId, fileType: "mp4")
        
        if !presigned.configured {
            print("⚠️ Storage not configured - returning mock URL")
            return presigned.publicUrl
        }
        
        return try await uploadData(videoData, to: presigned, contentType: "video/mp4")
    }
    
    // MARK: - Upload Audio
    
    func uploadAudio(url: URL, goalId: String) async throws -> String {
        // Read audio data
        let audioData = try Data(contentsOf: url)
        
        // Determine file type from extension
        let fileExtension = url.pathExtension.lowercased()
        let fileType = fileExtension == "m4a" ? "m4a" : "mp3"
        let contentType = fileExtension == "m4a" ? "audio/m4a" : "audio/mpeg"
        
        // Get presigned URL
        let presigned = try await getPresignedURL(goalId: goalId, fileType: fileType)
        
        if !presigned.configured {
            print("⚠️ Storage not configured - returning mock URL")
            return presigned.publicUrl
        }
        
        return try await uploadData(audioData, to: presigned, contentType: contentType)
    }
    
    // MARK: - Generic Upload
    
    private func uploadData(_ data: Data, to presigned: PresignedURLResponse, contentType: String) async throws -> String {
        guard let uploadURL = URL(string: presigned.uploadUrl) else {
            throw UploadError.invalidURL
        }
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
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

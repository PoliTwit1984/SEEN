//
//  NotificationService.swift
//  SEEN
//
//  Handles push notification registration
//

import Foundation
import UserNotifications
import UIKit
import Combine

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Request Permission
    
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            
            if granted {
                await registerForRemoteNotifications()
            }
            
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    // MARK: - Check Current Status
    
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    // MARK: - Register for Remote Notifications
    
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Handle Device Token
    
    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        
        print("Device token: \(token)")
        
        // Register with backend
        Task {
            await registerTokenWithBackend(token)
        }
    }
    
    func handleDeviceTokenError(_ error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Register Token with Backend
    
    private func registerTokenWithBackend(_ token: String) async {
        do {
            let request = RegisterDeviceRequest(token: token, platform: "ios")
            let _: EmptyResponse = try await APIClient.shared.request(
                path: "/devices",
                method: "POST",
                body: request
            )
            print("Device token registered with backend")
        } catch {
            print("Failed to register device token: \(error)")
        }
    }
    
    // MARK: - Unregister Token
    
    func unregisterToken() async {
        guard let token = deviceToken else { return }
        
        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                path: "/devices/\(token)",
                method: "DELETE"
            )
            deviceToken = nil
            print("Device token unregistered")
        } catch {
            print("Failed to unregister device token: \(error)")
        }
    }
}

// MARK: - Request Model

struct RegisterDeviceRequest: Encodable {
    let token: String
    let platform: String
}

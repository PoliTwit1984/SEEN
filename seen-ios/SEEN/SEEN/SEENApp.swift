//
//  SEENApp.swift
//  SEEN
//
//  Main app entry point
//

import SwiftUI
import UserNotifications

@main
struct SEENApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // Force dark mode
                .task {
                    await NotificationService.shared.checkAuthorizationStatus()
                }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // Handle device token registration
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationService.shared.handleDeviceToken(deviceToken)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            NotificationService.shared.handleDeviceTokenError(error)
        }
    }
    
    // Handle foreground notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle deep linking based on notification type
        if let type = userInfo["type"] as? String {
            switch type {
            case "high_five", "reaction":
                if let checkInId = userInfo["checkInId"] as? String {
                    print("Navigate to check-in: \(checkInId)")
                    // TODO: Implement deep linking
                }
            case "reminder", "missed":
                if let goalId = userInfo["goalId"] as? String {
                    print("Navigate to goal: \(goalId)")
                    // TODO: Implement deep linking
                }
            default:
                break
            }
        }
        
        completionHandler()
    }
}

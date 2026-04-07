//
//  NotificationService.swift
//  P2PMessenger
//
//  Created by Maksim on 03.04.2026.
//

import Foundation
import UserNotifications

struct NotificationService: NotificationServiceProtocol {
    
    func requestPermission() async -> Bool {
        do {
            let success = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            return success
        } catch {
            print("Notification Exception: \(error.localizedDescription)")
            return false
        }
    }
    
    func isPermissionGranted() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func sendMessage(title: String, message: String, subtitle: String = "", userInfo: [AnyHashable: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = message
        content.userInfo = userInfo
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Scheduling Error: \(error.localizedDescription)")
            }
        }
    }
    
    func sendPeopleCount(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Найдены новые собеседники!"
        content.body = "Найдено \(count) человек"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Scheduling Error: \(error.localizedDescription)")
            }
        }
    }
}

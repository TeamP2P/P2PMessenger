//
//  AppNotificationDelegate.swift
//  P2PMessenger
//
//  Created by Maksim on 03.04.2026.
//

import UIKit
import UserNotifications

final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var container: RootGraph?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification, 
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        completionHandler([.banner, .list, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                didReceive response: UNNotificationResponse, 
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        
        if let chatID = userInfo["chatID"] as? String {
            DispatchQueue.main.async {
                self.container?.router.selectedTab = .chats
                self.container?.router.activeChatId = chatID
            }
        }
        
        completionHandler()
    }
}

//
//  P2PMessengerApp.swift
//  P2PMessenger
//
//  Created by Maksim on 31.03.2026.
//

import SwiftUI
import SwiftData

@main
struct P2PMessengerApp: App {
    
    @State private var container = RootGraph()
    
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            container.appRootView
                .onAppear {
                    appDelegate.container = container
                }
                .preferredColorScheme(.light)
        }
    }
}

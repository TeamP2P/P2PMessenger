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
    @State private var container: DependencyContainer
    @StateObject private var chatViewModel: ChatViewModel
    
    @MainActor
    init() {
        _ = BluetoothMonitor.shared
        let networkService = MPCNetworkService()
        _container = State(initialValue: DependencyContainer(networkService: networkService))
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(networkService: networkService))
    }
    
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            AppRootView(chatViewModel: chatViewModel)
                .environment(container)
                .onAppear {
                    appDelegate.container = container
                }
        }
    }
}

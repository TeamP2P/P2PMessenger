//
//  RootGraph.swift
//  P2PMessenger
//
//  Created by Maksim on 03.04.2026.
//

import SwiftUI
import Observation

@Observable
final class RootGraph {
    // Services
    @ObservationIgnored
    let notificationService: NotificationServiceProtocol
    @ObservationIgnored
    let router: AppRouter
    @ObservationIgnored
    let bluetoothMonitor: BluetoothMonitor
    
    // Network layer
    @ObservationIgnored let networkService: MPCNetworkService
    @ObservationIgnored let coordinator: PeerSessionCoordinator

    
    // ViewModels
    @ObservationIgnored
    let bluetoothStatusViewModel: BluetoothStatusViewModel
    @ObservationIgnored
    let chatsRootViewModel: ChatsRootViewModel
    @ObservationIgnored
    let nearbyUserViewModel: NearbyUserViewModel
    @ObservationIgnored
    let welcomeScreenVM: WelcomeScreenVM
    @ObservationIgnored
    let commonChatViewModel: ChatScreenViewModel
    @ObservationIgnored
    let settingsViewModel: SettingsViewModel
    
    // Views
    @ObservationIgnored
    var settingsRootView: SettingsRootView
    @ObservationIgnored
    var commonChatRootView: CommonChatRootView
    @ObservationIgnored
    var chatsRootView: ChatsRootView
    @ObservationIgnored
    var appRootView: AppRootView
    
    
    @MainActor
    init() {
        //AppRouter
        self.router = AppRouter()
        
        // Notification
        self.notificationService = NotificationService()
        
        // Bluetooth
        self.bluetoothMonitor = BluetoothMonitor()
        self.bluetoothStatusViewModel = BluetoothStatusViewModel(monitor: bluetoothMonitor)
        
        // Network
        let svc = MPCNetworkService()
        let coord = PeerSessionCoordinator(networkService: svc)
        self.networkService = svc
        self.coordinator = coord
        
        // Nearby Users
        self.nearbyUserViewModel = NearbyUserViewModel(coordinator: coord)
        
        // Chats
        self.chatsRootViewModel = ChatsRootViewModel(
            chatListViewModel: ChatsListViewModel(
                chats: ChatListPreviewFixtures.stubChats
            ),
            chatScreenViewModel: ChatPreviewFixtures.newChat,
            nearbyUserViewModel: nearbyUserViewModel
        )
        self.chatsRootView = ChatsRootView (
            viewModel: chatsRootViewModel,
            router: router.chatsRouter
        )
        
        
        // Common Chat
        self.commonChatViewModel = ChatPreviewFixtures.publicChat
        self.commonChatRootView = CommonChatRootView(viewModel: commonChatViewModel)
        
        // Settings
        self.settingsViewModel = SettingsViewModel()
        self.settingsRootView = SettingsRootView(viewModel: settingsViewModel)
        
        // Onboarding
        self.welcomeScreenVM = WelcomeScreenVM(permissionManager: PermissionManager(notification: notificationService))
        
        self.appRootView = AppRootView(
            router: self.router,
            bluetoothStatusViewModel: bluetoothStatusViewModel,
            chatsRootView: chatsRootView,
            commonChatRootView: commonChatRootView,
            settingsRootView: settingsRootView,
            coordinator: coord

        )
    }
    
}

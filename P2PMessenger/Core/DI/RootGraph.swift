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
    @ObservationIgnored let networkService: MPCNetworkServiceImpl
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
    let commonChatViewModel: CommonChatViewModel
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
    var welcomeScreenView: WelcomeScreenView
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
        let svc = MPCNetworkServiceImpl()
        let coord = PeerSessionCoordinator(networkService: svc)
        let commonCoordinator = CommonChatCoordinator(networkService: svc, peerCoordinator: coord)
        self.networkService = svc
        self.coordinator = coord
        
        // Nearby Users
        self.nearbyUserViewModel = NearbyUserViewModel(coordinator: coord)
        self.commonChatViewModel = CommonChatViewModel(coordinator: commonCoordinator, networkSevice: svc)

        // Chats
        self.chatsRootViewModel = ChatsRootViewModel(
            chatListViewModel: ChatsListViewModel(coordinator: coord),
            chatScreenViewModel: ChatScreenViewModel(
                networkService: svc,
                headerStyle: .group(title: String(localized: "Чат"), subtitle: "")
            ),
            nearbyUserViewModel: nearbyUserViewModel,
            coordinator: coord
        )
        self.chatsRootView = ChatsRootView (
            viewModel: chatsRootViewModel,
            router: router.chatsRouter
        )

        // Common Chat
        self.commonChatRootView = CommonChatRootView(viewModel: commonChatViewModel)
        
        // Settings
        self.settingsViewModel = SettingsViewModel()
        self.settingsRootView = SettingsRootView(viewModel: settingsViewModel)
        
        // Onboarding
        self.welcomeScreenVM = WelcomeScreenVM(permissionManager: PermissionManager(notification: notificationService))
        self.welcomeScreenView = WelcomeScreenView(vm: welcomeScreenVM)
        
        self.appRootView = AppRootView(
            router: self.router,
            bluetoothStatusViewModel: bluetoothStatusViewModel,
            chatsRootView: chatsRootView,
            commonChatRootView: commonChatRootView,
            settingsRootView: settingsRootView,
            coordinator: coord,
            welcomeScreenView: welcomeScreenView
        )
    }
    
}

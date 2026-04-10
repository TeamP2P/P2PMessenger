//
//  RootGraph.swift
//  P2PMessenger
//
//  Created by Maksim on 03.04.2026.
//

import SwiftUI

final class RootGraph {
    // Services
    private let notificationService: NotificationServiceProtocol
    let router: AppRouterProtocol
    private let bluetoothMonitor: BluetoothMonitorProtocol

    // Storage
    private let profileStorage: UserProfileStorageProtocol
    private let identityProvider: LocalPeerIdentityReading
    private let onboardingState: OnboardingStateProtocol

    // Network layer
    private let networkService: MPCNetworkService
    private let coordinator: PeerSessionCoordinatorProtocol

    // ViewModels
    private let bluetoothStatusViewModel: BluetoothStatusViewModel
    private let chatsRootViewModel: ChatsRootViewModel
    private let nearbyUserViewModel: NearbyUserViewModel
    private let welcomeScreenVM: WelcomeScreenVM
    private let commonChatViewModel: CommonChatViewModel
    private let settingsViewModel: SettingsViewModel

    // Notifications
    private let chatNotifications: ChatNotificationsController

    // Views
    private let settingsRootView: SettingsRootView
    private let commonChatRootView: CommonChatRootView
    private let chatsRootView: ChatsRootView
    private let welcomeScreenView: WelcomeScreenView
    let appRootView: AppRootView

    @MainActor
    init() {
        if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "dev.p2pTeam.P2PMessenger")
        }
        // Core Services
        let router = AppRouter()
        self.router = router
        self.notificationService = NotificationService()
        self.bluetoothMonitor = BluetoothMonitor()
        self.bluetoothStatusViewModel = BluetoothStatusViewModel(monitor: bluetoothMonitor)

        // Storage & Identity
        let baseStorage: KeyValueStorageProtocol = AppKeyValueStorage(defaults: .standard)
        let profileStore = AppProfileStorage(storage: baseStorage)
        self.profileStorage = profileStore

        let permissionsStorage = PermissionsStorage(storage: baseStorage)
        let onboardingStorage = OnboardingStorage(storage: baseStorage)
        let chatHistoryStorage = ChatHistoryStorage(storage: baseStorage)

        self.onboardingState = OnboardingState(storage: onboardingStorage)
        let identityProvider = LocalPeerIdentityProvider(profileStorage: profileStore)
        self.identityProvider = identityProvider

        // Network Layer & Coordinators
        let svc = MPCNetworkServiceImpl(identityProvider: identityProvider)
        let coord = PeerSessionCoordinator(networkService: svc, storage: baseStorage)
        let commonCoord = CommonChatCoordinator(networkService: svc, peerCoordinator: coord, chatHistoryStorage: chatHistoryStorage)
        self.networkService = svc
        self.coordinator = coord

        // ViewModels & Features
        self.nearbyUserViewModel = NearbyUserViewModel(coordinator: coord)
        self.commonChatViewModel = CommonChatViewModel(coordinator: commonCoord, networkSevice: svc)

        self.chatsRootViewModel = ChatsRootViewModel(
            chatListViewModel: ChatsListViewModel(coordinator: coord, storage: baseStorage),
            nearbyUserViewModel: nearbyUserViewModel,
            coordinator: coord
        )

        self.settingsViewModel = SettingsViewModel(
            identityProvider: identityProvider,
            storage: baseStorage,
            onboardingState: self.onboardingState,
            storageSizeProvider: AppStorageSizeProvider()
        )

        self.welcomeScreenVM = WelcomeScreenVM(
            permissionManager: PermissionManager(notification: notificationService, permissionsStorage: permissionsStorage),
            identityProvider: identityProvider,
            onboardingState: self.onboardingState
        )
        self.welcomeScreenView = WelcomeScreenView(vm: welcomeScreenVM)

        // Views 
        self.chatsRootView = ChatsRootView(viewModel: chatsRootViewModel, router: router.chatsRouter, appRouter: router)
        self.commonChatRootView = CommonChatRootView(viewModel: commonChatViewModel, appRouter: router)
        self.settingsRootView = SettingsRootView(viewModel: settingsViewModel)

        self.appRootView = AppRootView(
            router: router,
            bluetoothStatusViewModel: bluetoothStatusViewModel,
            chatsRootView: chatsRootView,
            commonChatRootView: commonChatRootView,
            settingsRootView: settingsRootView,
            welcomeScreenVM: welcomeScreenVM,
            welcomeScreenView: welcomeScreenView,
            coordinator: coord,
            onboardingState: self.onboardingState
        )

        self.chatNotifications = ChatNotificationsController(
            peerCoordinator: coord,
            appRouter: router,
            notificationService: notificationService
        )
    }
}

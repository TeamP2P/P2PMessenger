//
//  AppRootView.swift
//  P2PMessenger
//
//  Created by Иван Иванов on 02.04.2026.
//

import SwiftUI

struct AppRootView: View {
    @Bindable var router: AppRouter
    let bluetoothStatusViewModel: BluetoothStatusViewModel
    let chatsRootView: ChatsRootView
    let commonChatRootView: CommonChatRootView
    let settingsRootView: SettingsRootView
    let coordinator: PeerSessionCoordinator
    let welcomeScreenView: WelcomeScreenView
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("isOnboardingPassed") private var isOnboardingPassed = false
    
    var body: some View {
        if isOnboardingPassed {
            TabView(selection: $router.selectedTab) {
                chatsRootView
                    .tabItem {
                        Label("Чаты", systemImage: "message")
                    }
                    .tag(AppTab.chats)
                
                commonChatRootView
                    .tabItem {
                        Label("Общий чат", systemImage: "person.2")
                    }
                    .tag(AppTab.commonChat)
                
                settingsRootView
                    .tabItem {
                        Label("Настройки", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
            }
            .tint(.p2PBlack)
            .fullScreenCover(isPresented: Binding(
                get: { bluetoothStatusViewModel.isBluetoothOff },
                set: { _ in }
            )) {
                NoBluetoothView()
            }
            .onAppear {
                coordinator.startIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:     coordinator.appBecameActive()
                case .background: coordinator.appMovedToBackground()
                default: break
                }
            }
        }
        else{
           welcomeScreenView
        }
       
    }
}

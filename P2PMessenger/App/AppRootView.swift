//
//  AppRouter.swift
//  P2PMessenger
//
//  Created by Иван Иванов on 02.04.2026.
//

import SwiftUI

struct AppRootView: View {
    @State private var appRouter = AppRouter()
    @StateObject private var bluetoothVM = BluetoothStatusViewModel()
    @Environment(DependencyContainer.self) var container
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: Binding(
            get: { container.router.selectedTab },
            set: { container.router.selectedTab = $0 }
        )) {
            ChatsRootView(
                viewModel: ChatsRootViewModel(
                    chatListViewModel: ChatsListViewModel(
                        chats: ChatListPreviewFixtures.stubChats
                    ),
                    chatScreenViewModel: ChatPreviewFixtures.newChat
                ),
                router: container.router.chatsRouter)
            .tabItem {
                Label("Чаты", systemImage: "message")
            }
            .tag(AppTab.chats)
            
            CommonChatRootView()
                .tabItem {
                    Label("Общий чат", systemImage: "person.2")
                }
                .tag(AppTab.commonChat)
            
            SettingsRootView(viewModel: SettingsViewModel())
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(.p2PBlack)
        .fullScreenCover(isPresented: $bluetoothVM.isBluetoothOff) {
            NoBluetoothView()
        }
        .onAppear {
            container.coordinator.startIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:     container.coordinator.appBecameActive()
            case .background: container.coordinator.appMovedToBackground()
            default: break
            }
        }
    }
    
    func openBluetoothSettings() {
        guard let settingsURL = URL(string: "App-Prefs:root=Bluetooth") else {
            return // UIApplication.openSettingsURLString
        }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
        
    }
    
}

#Preview {
    AppRootView()
        .environment(DependencyContainer())
}

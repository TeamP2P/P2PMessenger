//
//  AppRouter.swift
//  P2PMessenger
//
//  Created by Иван Иванов on 02.04.2026.
//

import SwiftUI

struct AppRootView: View {
    let chatViewModel: ChatViewModel

    @State private var appRouter = AppRouter()
    @StateObject private var bluetoothVM = BluetoothStatusViewModel()
    @Environment(DependencyContainer.self) var container
    
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
            
            CommonChatRootView(chatViewModel: chatViewModel)
                .tabItem {
                    Label(String(localized: "common_chat_title"), systemImage: "person.2")
                }
                .tag(AppTab.commonChat)
            
            SettingsRootView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(.p2PBlack)
        .fullScreenCover(isPresented: $bluetoothVM.isBluetoothOff) {
            NoBluetoothView()
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
    AppRootView(chatViewModel: ChatViewModel())
        .environment(DependencyContainer())
}

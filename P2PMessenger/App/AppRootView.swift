import SwiftUI
import SwiftData

struct AppRootView: View {
    @StateObject private var bluetoothViewModel = BluetoothStatusViewModel()
    @Environment(DependencyContainer.self) private var container
    @Query private var profiles: [LocalUserProfile]

    var body: some View {
        Group {
            if hasLocalProfile {
                mainTabs
            } else {
                WelcomeScreenView()
            }
        }
        .fullScreenCover(isPresented: $bluetoothViewModel.isBluetoothOff) {
            NoBluetoothView()
        }
    }

    private var hasLocalProfile: Bool {
        profiles.first != nil
    }

    private var mainTabs: some View {
        TabView(selection: selectedTabBinding) {
            ChatsRootView(
                viewModel: ChatsRootViewModel(
                    chatListViewModel: ChatsListViewModel(
                        chats: ChatListPreviewFixtures.stubChats
                    ),
                    chatScreenViewModel: ChatPreviewFixtures.newChat
                ),
                router: container.router.chatsRouter
            )
            .tabItem {
                Label("Чаты", systemImage: "message")
            }
            .tag(AppTab.chats)

            CommonChatRootView()
                .tabItem {
                    Label("Общий чат", systemImage: "person.2")
                }
                .tag(AppTab.commonChat)

            SettingsRootView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(.p2PBlack)
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { container.router.selectedTab },
            set: { container.router.selectedTab = $0 }
        )
    }
}

#Preview {
    AppRootView()
        .environment(DependencyContainer())
        .modelContainer(for: [LocalUserProfile.self, LocalChat.self, LocalMessage.self], inMemory: true)
}

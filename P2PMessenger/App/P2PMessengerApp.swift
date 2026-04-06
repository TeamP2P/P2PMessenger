import SwiftUI
import SwiftData

@main
struct P2PMessengerApp: App {
    @State private var container = DependencyContainer()
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var appDelegate

    init() {
        _ = BluetoothMonitor.shared
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(container)
                .modelContainer(sharedModelContainer)
                .onAppear {
                    appDelegate.container = container
                }
        }
    }

    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalUserProfile.self,
            LocalChat.self,
            LocalMessage.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

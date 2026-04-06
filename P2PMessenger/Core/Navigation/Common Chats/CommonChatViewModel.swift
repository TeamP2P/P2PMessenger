import Combine
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class CommonChatViewModel {
    var draftMessage = ""
    private(set) var localPeer = ChatPeer(id: "local", displayName: "")
    private(set) var meshMessages: [CoreChatMessage] = []
    private(set) var connectedPeers: [ChatPeer] = []

    @ObservationIgnored
    private let chatViewModel: ChatViewModel
    @ObservationIgnored
    private let timeFormatter: DateFormatter
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    init(
        chatViewModel: ChatViewModel,
        timeFormatter: DateFormatter? = nil
    ) {
        self.chatViewModel = chatViewModel
        self.timeFormatter = timeFormatter ?? Self.makeTimeFormatter()

        handleLocalPeerChanged(chatViewModel.localPeer)
        handleMeshMessagesChanged(chatViewModel.meshMessages)
        handleConnectedPeersChanged(chatViewModel.connectedPeers)
        bindChatViewModel()
    }

    var screenViewModel: ChatScreenViewModel {
        ChatScreenViewModel.groupChat(
            title: String(localized: "common_chat_title"),
            participantsSubtitle: participantsSubtitle,
            messages: meshMessages.map(makeChatMessage),
            timelineTitle: meshMessages.isEmpty ? nil : String(localized: "common_chat_timeline_title")
        )
    }

    func startIfNeeded() {
        chatViewModel.startIfNeeded()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            chatViewModel.appBecameActive()
        case .background:
            chatViewModel.appMovedToBackground()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    func sendMessage(_ text: String) {
        chatViewModel.sendMeshMessage(text)
    }

    private var participantsSubtitle: String {
        let ids = Set(connectedPeers.map(\.id)).union([localPeer.id])
        let count = ids.count

        if count % 100 >= 11 && count % 100 <= 14 {
            return String(format: String(localized: "common_chat_participants_count_many"), count)
        } else {
            switch count % 10 {
            case 1:
                return String(format: String(localized: "common_chat_participants_count_one"), count)
            case 2...4:
                return String(format: String(localized: "common_chat_participants_count_few"), count)
            default:
                return String(format: String(localized: "common_chat_participants_count_many"), count)
            }
        }
    }

    private func makeChatMessage(from message: CoreChatMessage) -> ChatMessage {
        if message.isIncoming {
            let participant = ChatParticipant(
                id: UUID(uuidString: message.senderID) ?? UUID(),
                name: message.senderDisplayName,
                isOnline: connectedPeers.contains(where: { $0.id == message.senderID })
            )

            return ChatMessage(
                id: message.id,
                sender: .incoming(participant),
                text: message.text,
                time: timeFormatter.string(from: message.timestamp)
            )
        }

        return ChatMessage(
            id: message.id,
            sender: .outgoing,
            text: message.text,
            time: timeFormatter.string(from: message.timestamp)
        )
    }

    private func handleLocalPeerChanged(_ peer: ChatPeer) {
        localPeer = peer
    }

    private func handleMeshMessagesChanged(_ messages: [CoreChatMessage]) {
        meshMessages = messages
    }

    private func handleConnectedPeersChanged(_ peers: [ChatPeer]) {
        connectedPeers = peers
    }

    private func bindChatViewModel() {
        chatViewModel.$localPeer
            .sink { [weak self] peer in
                self?.handleLocalPeerChanged(peer)
            }
            .store(in: &cancellables)

        chatViewModel.$meshMessages
            .sink { [weak self] messages in
                self?.handleMeshMessagesChanged(messages)
            }
            .store(in: &cancellables)

        chatViewModel.$connectedPeers
            .sink { [weak self] peers in
                self?.handleConnectedPeersChanged(peers)
            }
            .store(in: &cancellables)
    }

    private static func makeTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
}

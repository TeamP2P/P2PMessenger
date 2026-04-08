//
//  ChatsListViewModel.swift
//  P2PMessenger
//
//  Created by Трофим Чекмарев on 02.04.2026.
//

import Foundation

@MainActor
@Observable
final class ChatsListViewModel {
    private var chats: [ChatRowViewModel]

    @ObservationIgnored
    private let coordinator: PeerSessionCoordinator?
    @ObservationIgnored
    private var conversations: [String: ConversationEntry] = [:]

    var messageChats: [ChatRowViewModel] {
        chats
            .filter { $0.status == .active }
            .sorted { $0.timeOfLastMessage > $1.timeOfLastMessage }
    }

    var unreadMessagesCount: Int {
        messageChats.filter { $0.unreadCount > 0 }.count
    }

    init(coordinator: PeerSessionCoordinator) {
        self.coordinator = coordinator
        self.chats = []
        bind()
    }

    init(chats: [ChatRowViewModel]) {
        self.coordinator = nil
        self.chats = chats
    }

    // MARK: - Private

    private func bind() {
        guard let coordinator else { return }

        coordinator.subscribe { [weak self] message in
            guard let self else { return }
            guard let peerID = message.conversationPeerID else { return }

            let peer: ChatPeer
            if message.isIncoming {
                peer = ChatPeer(id: message.senderID, displayName: message.senderDisplayName)
            } else if let recipientID = message.recipientID {
                peer = ChatPeer(id: recipientID, displayName: message.recipientDisplayName ?? "")
            } else {
                return
            }

            if var entry = conversations[peerID] {
                entry.lastMessage = message.text
                entry.lastMessageTime = message.timestamp
                if message.isIncoming {
                    entry.unreadCount += 1
                }
                conversations[peerID] = entry
            } else {
                conversations[peerID] = ConversationEntry(
                    rowID: UUID(),
                    peer: peer,
                    lastMessage: message.text,
                    lastMessageTime: message.timestamp,
                    unreadCount: message.isIncoming ? 1 : 0
                )
            }
            rebuildChats()
        }

        coordinator.subscribePeerStateChanges { [weak self] in
            self?.rebuildChats()
        }
    }

    private func rebuildChats() {
        guard let coordinator else { return }
        chats = conversations.values.map { entry in
            ChatRowViewModel(
                id: entry.rowID,
                name: entry.peer.displayName,
                timeOfLastMessage: entry.lastMessageTime,
                lastMessage: entry.lastMessage,
                unreadCount: entry.unreadCount,
                isOnline: coordinator.isPeerConnected(entry.peer),
                status: .active
            )
        }
    }
}

// MARK: - ConversationEntry

private extension ChatsListViewModel {
    struct ConversationEntry {
        let rowID: UUID
        let peer: ChatPeer
        var lastMessage: String
        var lastMessageTime: Date
        var unreadCount: Int
    }
}


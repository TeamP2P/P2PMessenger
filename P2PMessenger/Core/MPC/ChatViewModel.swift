import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var localPeer = ChatPeer(id: "local", displayName: "")
    @Published private(set) var meshMessages: [CoreChatMessage] = []
    @Published private(set) var privateMessages: [String: [CoreChatMessage]] = [:]
    @Published private(set) var discoveredPeers: [ChatPeer] = []
    @Published private(set) var connectedPeers: [ChatPeer] = []
    @Published private(set) var connectingPeers: [ChatPeer] = []

    @Published var meshInputText = ""
    @Published var privateInputText = ""
    @Published var selectedPeer: ChatPeer?

    @Published var isPeersScreenPresented = false
    @Published var isRenameAlertPresented = false
    @Published var editableName = ""
    @Published var bannerText: String?
    @Published var isNetworkReady = false

    let networkService: MPCNetworkService

    private let defaults: UserDefaults
    private let meshStorageKey = "chat.mesh.messages"
    private let privateStorageKey = "chat.private.messages"
    private var seenMessageIDs = Set<UUID>()

    init(networkService: MPCNetworkService = MPCNetworkService(), defaults: UserDefaults = .standard) {
        self.networkService = networkService
        self.defaults = defaults
        self.networkService.delegate = self

        localPeer = networkService.localPeer
        editableName = localPeer.displayName

        restorePersistedState()
    }

    var localPeerName: String {
        localPeer.displayName
    }

    func startIfNeeded() {
        networkService.startIfNeeded()
        isNetworkReady = true
    }

    func appBecameActive() {
        networkService.resumeIfNeeded()
        isNetworkReady = true
    }

    func appMovedToBackground() {
        networkService.suspendForBackground()
        connectedPeers = []
        connectingPeers = []
        discoveredPeers = []
        isNetworkReady = false
    }

    func sendMeshMessage(_ text: String? = nil) {
        let messageText = text ?? meshInputText
        networkService.sendToMesh(text: messageText)

        if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            meshInputText = ""
        }
    }

    func sendPrivateMessage(to peer: ChatPeer? = nil) {
        let targetPeer = peer ?? selectedPeer
        guard let targetPeer else { return }

        let text = privateInputText
        networkService.sendPrivate(text: text, to: targetPeer)

        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            privateInputText = ""
        }
    }

    func openChat(with peer: ChatPeer) {
        isPeersScreenPresented = false
        selectedPeer = peer
    }

    func saveNewName() {
        networkService.updateDisplayName(editableName)
    }

    func messages(for peer: ChatPeer) -> [CoreChatMessage] {
        privateMessages[peer.id, default: []]
    }

    func clearBanner() {
        bannerText = nil
    }

    func isPeerConnected(_ peer: ChatPeer) -> Bool {
        connectedPeers.contains(where: { $0.id == peer.id })
    }

    func isPeerConnecting(_ peer: ChatPeer) -> Bool {
        connectingPeers.contains(where: { $0.id == peer.id })
    }

    private func append(_ message: CoreChatMessage) {
        guard seenMessageIDs.insert(message.id).inserted else { return }

        if let conversationPeerID = message.conversationPeerID {
            var messages = privateMessages[conversationPeerID, default: []]
            insert(message, into: &messages)
            privateMessages[conversationPeerID] = messages
        } else {
            insert(message, into: &meshMessages)
        }

        persistState()
    }

    private func insert(_ message: CoreChatMessage, into messages: inout [CoreChatMessage]) {
        if let last = messages.last, last.timestamp <= message.timestamp {
            messages.append(message)
            return
        }

        let index = messages.firstIndex(where: { $0.timestamp > message.timestamp }) ?? messages.endIndex
        messages.insert(message, at: index)
    }

    private func persistState() {
        if let data = try? JSONEncoder().encode(meshMessages) {
            defaults.set(data, forKey: meshStorageKey)
        }

        if let data = try? JSONEncoder().encode(privateMessages) {
            defaults.set(data, forKey: privateStorageKey)
        }
    }

    private func restorePersistedState() {
        let decoder = JSONDecoder()

        if let meshData = defaults.data(forKey: meshStorageKey),
           let messages = try? decoder.decode([CoreChatMessage].self, from: meshData) {
            meshMessages = messages.sorted { $0.timestamp < $1.timestamp }
        }

        if let privateData = defaults.data(forKey: privateStorageKey),
           let messages = try? decoder.decode([String: [CoreChatMessage]].self, from: privateData) {
            privateMessages = messages.mapValues { conversation in
                conversation.sorted { $0.timestamp < $1.timestamp }
            }
        }

        seenMessageIDs = Set(meshMessages.map(\.id))
        for conversation in privateMessages.values {
            seenMessageIDs.formUnion(conversation.map(\.id))
        }
    }
}

extension ChatViewModel: MPCNetworkServiceDelegate {
    func networkService(_ service: MPCNetworkService, didReceive message: CoreChatMessage) {
        if let recipientID = message.recipientID {
            guard recipientID == localPeer.id || message.senderID == localPeer.id else { return }
        }

        append(message)
    }

    func networkService(_ service: MPCNetworkService, peersChanged peers: [ChatPeer]) {
        discoveredPeers = peers

        if let selectedPeer {
            if let updated = peers.first(where: { $0.id == selectedPeer.id }) {
                self.selectedPeer = updated
            } else if !connectedPeers.contains(where: { $0.id == selectedPeer.id }) {
                self.selectedPeer = nil
            }
        }
    }

    func networkService(_ service: MPCNetworkService, connectedPeersChanged peers: [ChatPeer]) {
        connectedPeers = peers

        if let selectedPeer,
           let updated = peers.first(where: { $0.id == selectedPeer.id }) {
            self.selectedPeer = updated
        }
    }

    func networkService(_ service: MPCNetworkService, connectingPeersChanged peers: [ChatPeer]) {
        connectingPeers = peers
    }

    func networkService(_ service: MPCNetworkService, didUpdateLocalPeer peer: ChatPeer) {
        localPeer = peer
        editableName = peer.displayName
    }

    func networkService(_ service: MPCNetworkService, didEncounter error: NetworkServiceError) {
        bannerText = error.errorDescription
    }
}

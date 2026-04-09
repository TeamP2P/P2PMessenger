import Foundation
import MultipeerConnectivity

extension MPCNetworkServiceImpl: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.logNetwork("sessionStateChanged peer=\(peerID.displayName) state=\(state.rawValue) connectedPeers=\(session.connectedPeers.count)")

            guard let peerStableID = self.knownStableID(for: peerID) else {
                if state == .connected || state == .connecting {
                    self.logNetwork("sessionState unresolvedPeer marked peer=\(peerID.displayName) state=\(state.rawValue)")
                    self.markUnresolvedConnected(peerID)
                    self.sendHello(to: self.session.connectedPeers)
                } else if state == .notConnected {
                    self.logNetwork("sessionState unresolvedPeer removed peer=\(peerID.displayName)")
                    self.unmarkUnresolvedConnected(peerID)
                }
                self.refreshConnectedPeers()
                return
            }

            switch state {
            case .connected:
                self.logNetwork("sessionState connected remoteID=\(peerStableID)")
                self.markPeerConnected(peerStableID)
                self.unmarkUnresolvedConnected(peerID)
                self.unmarkPeerConnecting(peerStableID)
                self.unmarkPeerInvited(peerStableID)
                self.unmarkIncomingInvitation(peerStableID)
                self.clearRetrySchedule(for: peerStableID)
                self.cancelRetry(for: peerStableID)
                self.cancelInviteExpiry(for: peerStableID)
                self.publishConnectingPeers()
                self.publishConnectedPeers()
                self.handleTopologyChanged()
                self.sendHello(to: self.session.connectedPeers)

            case .connecting:
                self.logNetwork("sessionState connecting remoteID=\(peerStableID)")
                self.unmarkUnresolvedConnected(peerID)
                self.markPeerConnecting(peerStableID)
                self.publishConnectingPeers()

            case .notConnected:
                self.logNetwork("sessionState notConnected remoteID=\(peerStableID)")
                self.unmarkUnresolvedConnected(peerID)
                self.unmarkPeerConnected(peerStableID)
                self.unmarkPeerConnecting(peerStableID)
                self.unmarkPeerInvited(peerStableID)
                self.unmarkIncomingInvitation(peerStableID)
                self.cancelInviteExpiry(for: peerStableID)
                self.publishConnectingPeers()
                self.publishConnectedPeers()
                self.handleTopologyChanged()

                if self.lifecycleState.isRunning,
                   !self.lifecycleState.isSuspended,
                   self.containsDiscoveredPeer(peerStableID) {
                    self.logNetwork("sessionState schedulingRetry remoteID=\(peerStableID)")
                    self.scheduleRetry(for: peerStableID)
                }

            @unknown default:
                self.refreshConnectedPeers()
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let packet = try? decoder.decode(WirePacketDTO.self, from: data) {
            logNetwork("didReceive packet kind=\(packet.kind) fromPeer=\(peerID.displayName)")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.handle(packet: packet, from: peerID)
            }
            return
        }

        guard let wire = try? decoder.decode(WireMessageDTO.self, from: data) else {
            logNetwork("didReceive decodeFailed fromPeer=\(peerID.displayName)")
            publishError(.transportFailure("Не удалось декодировать входящее сообщение."))
            return
        }

        logNetwork("didReceive legacyWire fromPeer=\(peerID.displayName) senderID=\(wire.senderID)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.handleChat(wire, from: peerID)
        }
    }

    func handle(packet: WirePacketDTO, from peerID: MCPeerID) {
        switch packet.kind {
        case "chat":
            guard let chat = packet.chat else {
                publishError(.transportFailure("Получен некорректный пакет chat."))
                return
            }
            handleChat(chat, from: peerID)

        case "hello":
            guard let hello = packet.hello else {
                publishError(.transportFailure("Получен некорректный пакет hello."))
                return
            }
            handleHello(hello, from: peerID)

        default:
            publishError(.transportFailure("Получен неизвестный тип сетевого пакета."))
        }
    }

    func handleHello(_ hello: HelloMessageDTO, from peerID: MCPeerID) {
        logNetwork("handleHello senderID=\(hello.senderID) peer=\(peerID.displayName) leader=\(hello.leaderID) cluster=\(hello.clusterSize) epoch=\(hello.groupEpoch)")
        let info: [String: String] = [
            MPCNetworkConstants.discoveryUserIDKey: hello.senderID,
            MPCNetworkConstants.discoveryDisplayNameKey: hello.senderDisplayName,
            MPCNetworkConstants.discoveryLeaderIDKey: hello.leaderID,
            MPCNetworkConstants.discoveryClusterSizeKey: String(hello.clusterSize),
            MPCNetworkConstants.discoveryGroupEpochKey: String(hello.groupEpoch)
        ]

        updateDiscoveredPeer(peerID: peerID, info: info)
        unmarkUnresolvedConnected(peerID)

        if session.connectedPeers.contains(peerID) {
            markPeerConnected(hello.senderID)
            unmarkPeerConnecting(hello.senderID)
            publishConnectingPeers()
            publishConnectedPeers()
            handleTopologyChanged()
        }
    }

    func handleChat(_ wire: WireMessageDTO, from peerID: MCPeerID) {
        logNetwork("handleChat senderID=\(wire.senderID) recipientID=\(wire.recipientID ?? "mesh") fromPeer=\(peerID.displayName)")
        let senderInfo: [String: String] = [
            MPCNetworkConstants.discoveryUserIDKey: wire.senderID,
            MPCNetworkConstants.discoveryDisplayNameKey: wire.senderDisplayName,
            MPCNetworkConstants.discoveryLeaderIDKey: currentLeaderID,
            MPCNetworkConstants.discoveryClusterSizeKey: String(currentClusterSize),
            MPCNetworkConstants.discoveryGroupEpochKey: String(groupEpoch)
        ]

        if knownStableID(for: peerID) == nil {
            updateDiscoveredPeer(peerID: peerID, info: senderInfo)
        }

        let message = CoreChatMessage(
            id: wire.id,
            text: wire.text,
            senderID: wire.senderID,
            senderDisplayName: wire.senderDisplayName,
            recipientID: wire.recipientID,
            recipientDisplayName: wire.recipientDisplayName,
            timestamp: wire.timestamp,
            isIncoming: true
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            delegate?.networkService(self, didReceive: message)
        }
    }

    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) { }

    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) { }

    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) { }

    #if os(iOS)
    func session(_ session: MCSession,
                 didReceive certificate: [Any]?,
                 fromPeer peerID: MCPeerID,
                 certificateHandler: @escaping (Bool) -> Void) {
        logNetwork("certificateReceived peer=\(peerID.displayName) accepted=true")
        certificateHandler(true)
    }
    #endif
}

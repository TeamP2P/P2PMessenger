import Foundation
import MultipeerConnectivity

extension MPCNetworkServiceImpl: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        guard let context else {
            logNetwork("invitation rejected peer=\(peerID.displayName) reason=missingContext")
            invitationHandler(false, nil)
            publishError(.invalidInvitation)
            return
        }

        guard let invite = try? decoder.decode(InvitationContextDTO.self, from: context) else {
            logNetwork("invitation rejected peer=\(peerID.displayName) reason=decodeFailed")
            invitationHandler(false, nil)
            publishError(.invalidInvitation)
            return
        }

        guard invite.protocolVersion == MPCNetworkConstants.protocolVersion else {
            logNetwork("invitation rejected peer=\(peerID.displayName) reason=protocolMismatch remote=\(invite.protocolVersion) local=\(MPCNetworkConstants.protocolVersion)")
            invitationHandler(false, nil)
            publishError(.invalidInvitation)
            return
        }

        guard invite.senderID != localUserID else {
            logNetwork("invitation rejected peer=\(peerID.displayName) reason=selfSenderID")
            invitationHandler(false, nil)
            publishError(.invalidInvitation)
            return
        }

        updateDiscoveredPeer(
            peerID: peerID,
            info: [
                MPCNetworkConstants.discoveryUserIDKey: invite.senderID,
                MPCNetworkConstants.discoveryDisplayNameKey: invite.senderDisplayName,
                MPCNetworkConstants.discoveryLeaderIDKey: invite.senderLeaderID,
                MPCNetworkConstants.discoveryClusterSizeKey: String(invite.senderClusterSize),
                MPCNetworkConstants.discoveryGroupEpochKey: String(invite.senderGroupEpoch)
            ]
        )

        let remoteID = invite.senderID
        guard canAcceptInvitation(
            from: remoteID,
            senderLeaderID: invite.senderLeaderID,
            senderClusterSize: invite.senderClusterSize
        ) else {
            logNetwork("invitation rejected peer=\(peerID.displayName) remoteID=\(remoteID) reason=topologyDenied senderLeader=\(invite.senderLeaderID) senderCluster=\(invite.senderClusterSize) localLeader=\(currentLeaderID) localCluster=\(currentClusterSize)")
            invitationHandler(false, nil)
            return
        }

        unmarkPeerInvited(remoteID)
        cancelInviteExpiry(for: remoteID)
        markIncomingInvitation(remoteID)
        markPeerConnecting(remoteID)
        publishConnectingPeers()

        logNetwork("invitation accepted peer=\(peerID.displayName) remoteID=\(remoteID) senderLeader=\(invite.senderLeaderID) senderCluster=\(invite.senderClusterSize)")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logNetwork("didNotStartAdvertisingPeer error=\(error.localizedDescription)")
        publishError(.transportFailure(error.localizedDescription))
    }
}

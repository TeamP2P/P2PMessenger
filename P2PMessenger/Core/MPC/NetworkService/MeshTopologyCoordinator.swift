//
//  MeshTopologyCoordinator.swift
//  Sirius
//
//  Created by Екатерина on 06.04.2026.
//

import Foundation
import MultipeerConnectivity

enum MeshTopologyEvaluation {
    case none
    case retry(at: Date)
    case invite(peerID: MCPeerID)
}

struct MeshTopologyCoordinator {
    func currentLeaderID(
        localUserID: String,
        connectedPeerIDs: Set<String>
    ) -> String {
        ([localUserID] + Array(connectedPeerIDs)).min() ?? localUserID
    }

    func currentClusterSize(
        connectedPeerIDs: Set<String>
    ) -> Int {
        1 + connectedPeerIDs.count
    }

    func isLeader(
        localUserID: String,
        connectedPeerIDs: Set<String>
    ) -> Bool {
        currentLeaderID(localUserID: localUserID, connectedPeerIDs: connectedPeerIDs) == localUserID
    }

    func shouldInvitePeer(
        localUserID: String,
        lifecycleState: MPCNetworkLifecycleState,
        peerRegistry: PeerRegistry,
        peerState: DiscoveredPeerState
    ) -> Bool {
        let remoteID = peerState.peer.id

        guard lifecycleState.isRunning else { return false }
        guard !lifecycleState.isSuspended else { return false }
        guard !peerRegistry.connectedPeerIDs.contains(remoteID) else { return false }
        guard !peerRegistry.connectingPeerIDs.contains(remoteID) else { return false }
        guard !peerRegistry.incomingInvitationPeerIDs.contains(remoteID) else { return false }
        guard !peerRegistry.invitedPeerIDs.contains(remoteID) else { return false }
        guard peerRegistry.connectingPeerIDs.isEmpty else { return false }

        let currentLeaderID = currentLeaderID(
            localUserID: localUserID,
            connectedPeerIDs: peerRegistry.connectedPeerIDs
        )
        let currentClusterSize = currentClusterSize(
            connectedPeerIDs: peerRegistry.connectedPeerIDs
        )
        let isLeader = isLeader(
            localUserID: localUserID,
            connectedPeerIDs: peerRegistry.connectedPeerIDs
        )

        let remoteClusterSize = peerState.clusterSize

        if peerState.leaderID == currentLeaderID && currentClusterSize > 1 && remoteClusterSize > 1 {
            return false
        }

        if currentClusterSize == 1 && remoteClusterSize == 1 {
            return localUserID.compare(remoteID) == .orderedAscending
        }

        if currentClusterSize > 1 && remoteClusterSize == 1 {
            return isLeader
        }

        if currentClusterSize == 1 && remoteClusterSize > 1 {
            return false
        }

        return false
    }

    func canAcceptInvitation(
        localUserID: String,
        peerRegistry: PeerRegistry,
        remoteID: String,
        senderLeaderID: String,
        senderClusterSize: Int
    ) -> Bool {
        if peerRegistry.connectedPeerIDs.contains(remoteID) {
            return true
        }

        let hasOtherConnectingPeers = !peerRegistry.connectingPeerIDs
            .subtracting([remoteID])
            .isEmpty
        if hasOtherConnectingPeers {
            return false
        }

        let currentClusterSize = currentClusterSize(
            connectedPeerIDs: peerRegistry.connectedPeerIDs
        )

        if currentClusterSize == 1 {
            return true
        }

        if senderClusterSize == 1 {
            return true
        }

        let currentLeaderID = currentLeaderID(
            localUserID: localUserID,
            connectedPeerIDs: peerRegistry.connectedPeerIDs
        )

        if senderLeaderID == currentLeaderID {
            return true
        }

        return false
    }

    func evaluateConnection(
        for peerStableID: String,
        localUserID: String,
        lifecycleState: MPCNetworkLifecycleState,
        peerRegistry: PeerRegistry,
        retryAfterByPeerID: [String: Date],
        now: Date = Date()
    ) -> MeshTopologyEvaluation {
        guard let state = peerRegistry.peerState(for: peerStableID) else {
            return .none
        }

        guard shouldInvitePeer(
            localUserID: localUserID,
            lifecycleState: lifecycleState,
            peerRegistry: peerRegistry,
            peerState: state
        ) else {
            return .none
        }

        if let retryAt = retryAfterByPeerID[peerStableID], retryAt > now {
            return .retry(at: retryAt)
        }

        return .invite(peerID: state.peerID)
    }

    func shouldScheduleReevaluation(
        localUserID: String,
        lifecycleState: MPCNetworkLifecycleState,
        peerRegistry: PeerRegistry
    ) -> Bool {
        guard !lifecycleState.isSuspended else { return false }

        return isLeader(
            localUserID: localUserID,
            connectedPeerIDs: peerRegistry.connectedPeerIDs
        )
    }
}

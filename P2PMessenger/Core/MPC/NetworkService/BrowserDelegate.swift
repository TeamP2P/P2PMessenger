import Foundation
import MultipeerConnectivity

extension MPCNetworkServiceImpl: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard let info else {
            logNetwork("foundPeer dropped peer=\(peerID.displayName) reason=missingDiscoveryInfo")
            return
        }

        guard let remoteID = info[MPCNetworkConstants.discoveryUserIDKey] else {
            logNetwork("foundPeer dropped peer=\(peerID.displayName) reason=missingRemoteUserID info=\(info.description)")
            return
        }

        guard remoteID != localUserID else {
            logNetwork("foundPeer dropped peer=\(peerID.displayName) reason=selfPeer")
            return
        }

        let remoteLeader = info[MPCNetworkConstants.discoveryLeaderIDKey] ?? "unknown"
        let remoteCluster = info[MPCNetworkConstants.discoveryClusterSizeKey] ?? "unknown"
        logNetwork("foundPeer accepted remoteID=\(remoteID) peer=\(peerID.displayName) remoteLeader=\(remoteLeader) remoteCluster=\(remoteCluster)")
        updateDiscoveredPeer(peerID: peerID, info: info)
        evaluateConnection(for: remoteID)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logNetwork("lostPeer peer=\(peerID.displayName)")
        removeDiscoveredPeer(peerID: peerID)
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logNetwork("didNotStartBrowsingForPeers error=\(error.localizedDescription)")
        publishError(.transportFailure(error.localizedDescription))
    }
}

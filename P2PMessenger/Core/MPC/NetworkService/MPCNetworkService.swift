import Foundation
import MultipeerConnectivity
import OSLog
//import sys
import UIKit

protocol MPCNetworkService {
    var session: MCSession { get }
    var browser: MCNearbyServiceBrowser? { get }
    var lifecycleState: MPCNetworkLifecycleState { get }
    var advertiserState: MPCNetworkAdvertiserState { get }
    var groupEpoch: Int { get }
    var localPeer: ChatPeer { get }
    
    func startIfNeeded()
    func resumeIfNeeded()
    func suspendForBackground()
    
    func updateDisplayName(_ newName: String)
    func sendToMesh(text: String) -> Bool
    
    func sendPrivate(text: String, to peer: ChatPeer)
}

final class MPCNetworkServiceImpl: NSObject, MPCNetworkService, LocalPeerIdentityDelegate {
    weak var delegate: MPCNetworkServiceDelegate?
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "P2PMessenger", category: "MPCNetwork")

    private let identityProvider: LocalPeerIdentityProvider
    private let topologyCoordinator = MeshTopologyCoordinator()
    private let scheduler = ConnectionScheduler()
    private let peerRegistry = PeerRegistry()

    var localUserID: String { identityProvider.localUserID }
    private var myPeerID: MCPeerID { identityProvider.peerID }
    var groupEpoch: Int { identityProvider.groupEpoch }

    var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser?

    var lifecycleState = MPCNetworkLifecycleState()
    var advertiserState = MPCNetworkAdvertiserState()

    private let encoder = JSONEncoder()
    let decoder = JSONDecoder()


    init(identityProvider: LocalPeerIdentityProvider) {
        self.identityProvider = identityProvider
        
        self.session = MCSession(peer: identityProvider.peerID, securityIdentity: nil, encryptionPreference: .required)

        super.init()

        identityProvider.delegate = self

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        configureSession()
    }

    // MARK: - LocalPeerIdentityDelegate

    func identityProviderDidChangeIdentity() {
        restartAfterIdentityChange()
    }

    deinit {
        stopDiscovery()
        session.disconnect()
    }

    var localPeer: ChatPeer {
        identityProvider.localPeer
    }

    var currentLeaderID: String {
        topologyCoordinator.currentLeaderID(
            localUserID: localUserID,
            connectedPeerIDs: peerRegistry.connectedPeerIDs
        )
    }

    var currentClusterSize: Int {
        topologyCoordinator.currentClusterSize(
            connectedPeerIDs: peerRegistry.connectedPeerIDs
        )
    }

    var isLeader: Bool {
        topologyCoordinator.isLeader(
            localUserID: localUserID,
            connectedPeerIDs: peerRegistry.connectedPeerIDs
        )
    }

    func startIfNeeded() {
        guard !lifecycleState.hasStartedOnce else { return }
        lifecycleState.hasStartedOnce = true
        lifecycleState.isSuspended = false
        logNetwork("startIfNeeded localUserID=\(localUserID) displayName=\(localPeer.displayName)")
        startTransport()
    }

    func resumeIfNeeded() {
        guard lifecycleState.hasStartedOnce else {
            startIfNeeded()
            return
        }
        guard lifecycleState.isSuspended else { return }

        lifecycleState.isSuspended = false
        recreateSession()
        clearTransientConnectionState()
        logNetwork("resumeIfNeeded localUserID=\(localUserID)")
        startTransport()
    }

    func suspendForBackground() {
        guard lifecycleState.hasStartedOnce else { return }
        guard !lifecycleState.isSuspended else { return }

        lifecycleState.isSuspended = true
        logNetwork("suspendForBackground connectedPeers=\(session.connectedPeers.count)")
        stopDiscovery()

        session.disconnect()
        clearTransientConnectionState()

        publishFoundPeers()
        publishConnectingPeers()
        publishConnectedPeers()
    }

    func restartAfterIdentityChange() {
        lifecycleState.isSuspended = false
        stopDiscovery()
        recreateSession()
        clearTransientConnectionState()
        logNetwork("restartAfterIdentityChange newDisplayName=\(localPeer.displayName) groupEpoch=\(groupEpoch)")
        startTransport()
    }

    func updateDisplayName(_ newName: String) {
        _ = identityProvider.updateDisplayName(newName)
    }

    func sendToMesh(text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            publishError(.emptyMessage)
            return false
        }

        let peers = session.connectedPeers
        guard !peers.isEmpty else {
            publishError(.noConnectedPeers)
            return false
        }

        let wire = WireMessageDTO(
            id: UUID(),
            text: trimmed,
            senderID: localUserID,
            senderDisplayName: localPeer.displayName,
            recipientID: nil,
            recipientDisplayName: nil,
            timestamp: Date()
        )

        guard sendChat(wire, to: peers) else { return false }
        publishLocalCopy(from: wire)
        return true
    }

    func sendPrivate(text: String, to peer: ChatPeer) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            publishError(.emptyMessage)
            return
        }

        guard peerRegistry.connectedPeerIDs.contains(peer.id),
              let targetPeerID = peerRegistry.peerState(for: peer.id)?.peerID else {
            publishError(.peerUnavailable)
            return
        }

        let wire = WireMessageDTO(
            id: UUID(),
            text: trimmed,
            senderID: localUserID,
            senderDisplayName: localPeer.displayName,
            recipientID: peer.id,
            recipientDisplayName: peer.displayName,
            timestamp: Date()
        )

        guard sendChat(wire, to: [targetPeerID]) else { return }
        publishLocalCopy(from: wire)
    }

    private func configureSession() {
        session.delegate = self
    }

    private func recreateSession() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        configureSession()
    }

    private func startTransport() {
        lifecycleState.isRunning = true

        startAdvertiser()

        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: MPCNetworkConstants.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
        logNetwork("startTransport serviceType=\(MPCNetworkConstants.serviceType) leader=\(currentLeaderID) clusterSize=\(currentClusterSize)")

        notifyLocalPeerChanged()
        publishFoundPeers()
        publishConnectingPeers()
        publishConnectedPeers()
        scheduleReevaluation(after: 0.8)
    }

    private func stopDiscovery() {
        lifecycleState.isRunning = false
        logNetwork("stopDiscovery connectedPeers=\(session.connectedPeers.count)")

        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil

        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil

        scheduler.cancelReevaluation()
        scheduler.cancelAllRetries()
        scheduler.cancelAllInviteExpiry()
        scheduler.clearAllRetryDates()

        peerRegistry.clearInvitationState()

        advertiserState.lastAdvertisedLeaderID = nil
        advertiserState.lastAdvertisedClusterSize = nil
        advertiserState.lastAdvertisedGroupEpoch = nil
    }

    private func clearTransientConnectionState() {
        peerRegistry.clearTransientConnectionState()
    }

    private func startAdvertiser() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil

        let advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: discoveryInfo(),
            serviceType: MPCNetworkConstants.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
        logNetwork("startAdvertiser leader=\(currentLeaderID) clusterSize=\(currentClusterSize) epoch=\(groupEpoch)")

        advertiserState.lastAdvertisedLeaderID = currentLeaderID
        advertiserState.lastAdvertisedClusterSize = currentClusterSize
        advertiserState.lastAdvertisedGroupEpoch = groupEpoch
    }

    func refreshAdvertiserIfNeeded() {
        guard lifecycleState.isRunning else { return }

        let needsRefresh =
            advertiserState.lastAdvertisedLeaderID != currentLeaderID ||
            advertiserState.lastAdvertisedClusterSize != currentClusterSize ||
            advertiserState.lastAdvertisedGroupEpoch != groupEpoch

        guard needsRefresh else { return }
        startAdvertiser()
    }

    func discoveryInfo() -> [String: String] {
        [
            MPCNetworkConstants.discoveryUserIDKey: localUserID,
            MPCNetworkConstants.discoveryDisplayNameKey: localPeer.displayName,
            MPCNetworkConstants.discoveryLeaderIDKey: currentLeaderID,
            MPCNetworkConstants.discoveryClusterSizeKey: String(currentClusterSize),
            MPCNetworkConstants.discoveryGroupEpochKey: String(groupEpoch)
        ]
    }

    func invitationContext() -> Data? {
        let payload = InvitationContextDTO(
            protocolVersion: MPCNetworkConstants.protocolVersion,
            senderID: localUserID,
            senderDisplayName: localPeer.displayName,
            senderLeaderID: currentLeaderID,
            senderClusterSize: currentClusterSize,
            senderGroupEpoch: groupEpoch
        )
        return try? encoder.encode(payload)
    }

    func knownStableID(for peerID: MCPeerID) -> String? {
        peerRegistry.knownStableID(for: peerID)
    }

    func updateDiscoveredPeer(peerID: MCPeerID, info: [String: String]?) {
        guard let peerStableID = peerRegistry.updateDiscoveredPeer(
            localUserID: localUserID,
            peerID: peerID,
            info: info
        ) else {
            return
        }

        publishFoundPeers()
        refreshConnectedPeers()
        evaluateConnection(for: peerStableID)
    }

    func removeDiscoveredPeer(peerID: MCPeerID) {
        guard let peerStableID = peerRegistry.removeDiscoveredPeer(peerID: peerID) else { return }

        cancelRetry(for: peerStableID)
        cancelInviteExpiry(for: peerStableID)
        scheduler.clearRetryDate(for: peerStableID)

        publishFoundPeers()
        publishConnectingPeers()
        publishConnectedPeers()
        handleTopologyChanged()
    }

    func cleanupPeerState(for peerStableID: String, removeDiscovery: Bool = false) {
        peerRegistry.cleanupPeerState(for: peerStableID, removeDiscovery: removeDiscovery)
        cancelRetry(for: peerStableID)
        cancelInviteExpiry(for: peerStableID)
        scheduler.clearRetryDate(for: peerStableID)
    }

    private func sendChat(_ wireMessage: WireMessageDTO, to peers: [MCPeerID]) -> Bool {
        sendPacket(.chat(wireMessage), to: peers)
    }

    func sendHello(to peers: [MCPeerID]) {
        guard !peers.isEmpty else { return }

        let hello = HelloMessageDTO(
            senderID: localUserID,
            senderDisplayName: localPeer.displayName,
            leaderID: currentLeaderID,
            clusterSize: currentClusterSize,
            groupEpoch: groupEpoch
        )

        _ = sendPacket(.hello(hello), to: peers, reportErrors: false)
    }

    @discardableResult
    private func sendPacket(_ packet: WirePacketDTO, to peers: [MCPeerID], reportErrors: Bool = true) -> Bool {
        guard !peers.isEmpty else {
            if reportErrors {
                publishError(.peerUnavailable)
            }
            return false
        }

        do {
            let data = try encoder.encode(packet)
            try session.send(data, toPeers: peers, with: .reliable)
            return true
        } catch {
            if reportErrors {
                publishError(.transportFailure(error.localizedDescription))
            }
            return false
        }
    }

    private func publishLocalCopy(from wire: WireMessageDTO) {
        let localCopy = CoreChatMessage(
            id: wire.id,
            text: wire.text,
            senderID: wire.senderID,
            senderDisplayName: wire.senderDisplayName,
            recipientID: wire.recipientID,
            recipientDisplayName: wire.recipientDisplayName,
            timestamp: wire.timestamp,
            isIncoming: false
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            delegate?.networkService(self, didReceive: localCopy)
        }
    }

    func publishFoundPeers() {
        let peers = peerRegistry.discoveredPeersSorted()

        Task { @MainActor [weak self] in
            guard let self else { return }
            delegate?.networkService(self, peersChanged: peers)
        }
    }

    func publishConnectedPeers() {
        let peers = peerRegistry.connectedPeersSorted()

        Task { @MainActor [weak self] in
            guard let self else { return }
            delegate?.networkService(self, connectedPeersChanged: peers)
        }
    }

    func publishConnectingPeers() {
        let peers = peerRegistry.connectingPeersSorted()

        Task { @MainActor [weak self] in
            guard let self else { return }
            delegate?.networkService(self, connectingPeersChanged: peers)
        }
    }

    private func notifyLocalPeerChanged() {
        let peer = localPeer

        Task { @MainActor [weak self] in
            guard let self else { return }
            delegate?.networkService(self, didUpdateLocalPeer: peer)
        }
    }

    func publishError(_ error: NetworkServiceError) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            delegate?.networkService(self, didEncounter: error)
        }
    }

    func canAcceptInvitation(
        from remoteID: String,
        senderLeaderID: String,
        senderClusterSize: Int
    ) -> Bool {
        topologyCoordinator.canAcceptInvitation(
            localUserID: localUserID,
            peerRegistry: peerRegistry,
            remoteID: remoteID,
            senderLeaderID: senderLeaderID,
            senderClusterSize: senderClusterSize
        )
    }

    func evaluateConnection(for peerStableID: String) {
        let evaluation = topologyCoordinator.evaluateConnection(
            for: peerStableID,
            localUserID: localUserID,
            lifecycleState: lifecycleState,
            peerRegistry: peerRegistry,
            retryAfterByPeerID: currentRetryAfterByPeerID
        )

        switch evaluation {
        case .none:
            if let state = peerRegistry.peerState(for: peerStableID) {
                logNetwork("evaluateConnection none remoteID=\(peerStableID) remoteLeader=\(state.leaderID) remoteCluster=\(state.clusterSize) localLeader=\(currentLeaderID) localCluster=\(currentClusterSize)")
            }
            return

        case .retry(let retryAt):
            logNetwork("evaluateConnection retry remoteID=\(peerStableID) retryAt=\(retryAt.ISO8601Format())")
            scheduleRetry(for: peerStableID, at: retryAt)

        case .invite(let peerID):
            logNetwork("evaluateConnection invite remoteID=\(peerStableID) peerDisplayName=\(peerID.displayName) connectedPeers=\(session.connectedPeers.count)")
            peerRegistry.markInvited(peerStableID)
            peerRegistry.markConnecting(peerStableID)
            publishConnectingPeers()

            browser?.invitePeer(
                peerID,
                to: session,
                withContext: invitationContext(),
                timeout: MPCNetworkConstants.invitationTimeout
            )

            scheduleInviteExpiry(for: peerStableID)
        }
    }

    func handleTopologyChanged() {
        refreshAdvertiserIfNeeded()
        publishConnectingPeers()

        if topologyCoordinator.shouldScheduleReevaluation(
            localUserID: localUserID,
            lifecycleState: lifecycleState,
            peerRegistry: peerRegistry
        ) {
            scheduleReevaluation(after: 0.3)
        }
    }

    var currentRetryAfterByPeerID: [String: Date] {
        peerRegistry.allPeerIDs.reduce(into: [:]) { result, peerID in
            if let retryDate = scheduler.retryDate(for: peerID) {
                result[peerID] = retryDate
            }
        }
    }

    func scheduleReevaluation(after delay: TimeInterval = MPCNetworkConstants.reevaluateDelay) {
        scheduler.scheduleReevaluation(
            after: delay,
            isRunning: { [weak self] in self?.lifecycleState.isRunning ?? false },
            isSuspended: { [weak self] in self?.lifecycleState.isSuspended ?? true }
        ) { [weak self] in
            guard let self else { return }

            let ids = self.peerRegistry.allPeerIDs.sorted()
            for peerStableID in ids {
                self.evaluateConnection(for: peerStableID)
            }
        }
    }

    func refreshConnectedPeers() {
        let result = peerRegistry.refreshConnectedPeers(using: session.connectedPeers)
        if result.connectedChanged || result.staleConnectingRemoved {
            let connectedIDs = peerRegistry.connectedPeersSorted().map(\.id).joined(separator: ",")
            logNetwork("refreshConnectedPeers connectedCount=\(session.connectedPeers.count) connectedChanged=\(result.connectedChanged) staleConnectingRemoved=\(result.staleConnectingRemoved) connectedIDs=[\(connectedIDs)]")
        }

        if result.connectedChanged {
            publishConnectedPeers()
            handleTopologyChanged()
        }

        if result.staleConnectingRemoved {
            publishConnectingPeers()
        }
    }

    func scheduleRetry(for peerStableID: String, at date: Date? = nil) {
        if let date {
            logNetwork("scheduleRetry remoteID=\(peerStableID) at=\(date.ISO8601Format())")
        } else {
            logNetwork("scheduleRetry remoteID=\(peerStableID) usingDefaultBackoff=\(MPCNetworkConstants.retryBackoff)")
        }
        scheduler.scheduleRetry(
            for: peerStableID,
            at: date,
            isRunning: lifecycleState.isRunning,
            isSuspended: lifecycleState.isSuspended,
            defaultBackoff: MPCNetworkConstants.retryBackoff
        ) { [weak self] in
            self?.evaluateConnection(for: peerStableID)
        }
    }

    func cancelRetry(for peerStableID: String) {
        scheduler.cancelRetry(for: peerStableID)
    }

    func scheduleInviteExpiry(for peerStableID: String) {
        logNetwork("scheduleInviteExpiry remoteID=\(peerStableID) after=\(MPCNetworkConstants.inviteReapTime)")
        scheduler.scheduleInviteExpiry(
            for: peerStableID,
            after: MPCNetworkConstants.inviteReapTime
        ) { [weak self] in
            guard let self else { return }
            guard !self.peerRegistry.connectedPeerIDs.contains(peerStableID) else { return }

            self.peerRegistry.unmarkInvited(peerStableID)
            self.peerRegistry.unmarkConnecting(peerStableID)
            self.logNetwork("inviteExpired remoteID=\(peerStableID)")
            self.publishConnectingPeers()
            self.scheduleRetry(for: peerStableID)
        }
    }

    func cancelInviteExpiry(for peerStableID: String) {
        scheduler.cancelInviteExpiry(for: peerStableID)
    }

    func clearRetrySchedule(for peerStableID: String) {
        scheduler.clearRetryDate(for: peerStableID)
    }

    func markPeerConnected(_ peerStableID: String) {
        peerRegistry.markConnected(peerStableID)
    }

    func unmarkPeerConnected(_ peerStableID: String) {
        peerRegistry.unmarkConnected(peerStableID)
    }

    func markPeerConnecting(_ peerStableID: String) {
        peerRegistry.markConnecting(peerStableID)
    }

    func unmarkPeerConnecting(_ peerStableID: String) {
        peerRegistry.unmarkConnecting(peerStableID)
    }

    func markPeerInvited(_ peerStableID: String) {
        peerRegistry.markInvited(peerStableID)
    }

    func unmarkPeerInvited(_ peerStableID: String) {
        peerRegistry.unmarkInvited(peerStableID)
    }

    func markIncomingInvitation(_ peerStableID: String) {
        peerRegistry.markIncomingInvitation(peerStableID)
    }

    func unmarkIncomingInvitation(_ peerStableID: String) {
        peerRegistry.unmarkIncomingInvitation(peerStableID)
    }

    func markUnresolvedConnected(_ peerID: MCPeerID) {
        peerRegistry.markUnresolvedConnected(peerID)
    }

    func unmarkUnresolvedConnected(_ peerID: MCPeerID) {
        peerRegistry.unmarkUnresolvedConnected(peerID)
    }

    func containsDiscoveredPeer(_ peerStableID: String) -> Bool {
        peerRegistry.peerState(for: peerStableID) != nil
    }

    func logNetwork(_ message: String) {
#if DEBUG
        let osVersion = UIDevice.current.systemVersion
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let userSuffix = String(localUserID.suffix(6))
        let model = deviceModelIdentifier()
        let prefix = "[ios=\(osVersion) model=\(model) app=\(appVersion)(\(appBuild)) user=\(userSuffix)]"
        Self.logger.debug("\(prefix, privacy: .public) \(message, privacy: .public)")
#endif
    }

    private func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machine = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { cString in
                String(cString: cString)
            }
        }

        return machine
    }
}

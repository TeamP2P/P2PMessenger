//
//  PermissionManager.swift
//  P2PMessenger
//
//  Created by Иван Иванов on 02.04.2026.
//

import CoreBluetooth
import MultipeerConnectivity
import Network
import Observation

@MainActor
@Observable
final class PermissionManager: NSObject {

    var bluetoothState: PermissionState = .needAction
    var localNetworkState: PermissionState = .needAction
    var nearbyState: PermissionState = .needAction
    var notificationsState: PermissionState = .needAction

    @ObservationIgnored
    private var centralManager: CBCentralManager?
    @ObservationIgnored
    private var localNetworkBrowser: NWBrowser?
    @ObservationIgnored
    private var mcBrowser: MCNearbyServiceBrowser?
    @ObservationIgnored
    private let notificationService: NotificationServiceProtocol
    
    private let fakeDisplayName: String = "probe"

    private enum Keys {
        static let localNetwork = "permission.localNetwork.granted"
        static let nearby = "permission.nearby.granted"
    }

    init(notification: NotificationServiceProtocol) {
        self.notificationService = notification
        super.init()
        restorePersistedStates()
        checkBluetoothStatus()
        checkNotificationsStatus()
    }

    // MARK: - Restore on launch

    private func restorePersistedStates() {
        if UserDefaults.standard.bool(forKey: Keys.localNetwork) {
            localNetworkState = .granted
        }
        if UserDefaults.standard.bool(forKey: Keys.nearby) {
            nearbyState = .granted
        }
    }

    private func checkBluetoothStatus() {
        switch CBCentralManager.authorization {
        case .allowedAlways:
            bluetoothState = .granted
        default:
            bluetoothState = .needAction
        }
    }

    private func checkNotificationsStatus() {
        Task {
            let granted = await notificationService.isPermissionGranted()
            self.notificationsState = granted ? .granted : .needAction
        }
    }

    // MARK: - Request

    func requestBluetooth() {
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func requestLocalNetwork() {
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_p2p-msg._tcp", domain: nil), using: params)
        localNetworkBrowser = browser
        browser.stateUpdateHandler = { [weak self] state in
            guard case .failed = state else { return }
            DispatchQueue.main.async {
                self?.localNetworkState = .granted
                UserDefaults.standard.set(true, forKey: Keys.localNetwork)
                browser.cancel()
            }
        }
        browser.browseResultsChangedHandler = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.localNetworkState = .granted
                UserDefaults.standard.set(true, forKey: Keys.localNetwork)
                browser.cancel()
            }
        }
        browser.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard self?.localNetworkState == .needAction else { return }
            self?.localNetworkState = .granted
            UserDefaults.standard.set(true, forKey: Keys.localNetwork)
            browser.cancel()
        }
    }

    func requestNearbyDiscovery() {
        let peerID = MCPeerID(displayName: fakeDisplayName)
        mcBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: "p2p-msg")
        mcBrowser?.delegate = self
        mcBrowser?.startBrowsingForPeers()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.nearbyState = .granted
            UserDefaults.standard.set(true, forKey: Keys.nearby)
            self?.mcBrowser?.stopBrowsingForPeers()
        }
    }

    func requestNotifications() {
        Task {
            let _ = await notificationService.requestPermission()
            checkNotificationsStatus()
        }
    }
}

extension PermissionManager: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state != .unknown && central.state != .resetting else { return }
        bluetoothState = central.state == .poweredOn ? .granted : .needAction
    }
}

extension PermissionManager: @preconcurrency MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.nearbyState = .granted
            UserDefaults.standard.set(true, forKey: Keys.nearby)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {}
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

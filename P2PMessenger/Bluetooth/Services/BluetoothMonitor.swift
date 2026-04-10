//
//  BluetoothMonitor.swift
//  P2PMessenger
//
//  Created by Sergei on 2026/04/03.
//

import CoreBluetooth
import Observation

@MainActor
@Observable
final class BluetoothMonitor: NSObject, BluetoothMonitorProtocol {
    private(set) var managerState: CBManagerState = .unknown

    var isBluetoothEnabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") {
            return true
        }
        return managerState == .poweredOn
    }

    @ObservationIgnored
    private var centralManager: CBCentralManager!

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

}

extension BluetoothMonitor: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        managerState = central.state
    }
}

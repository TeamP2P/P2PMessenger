//
//  BluetoothStatusViewModel.swift
//  P2PMessenger
//
//  Created by Sergei on 2026/04/03.
//

import Observation

@MainActor
@Observable
final class BluetoothStatusViewModel {
    
    private let monitor: BluetoothMonitor
    
    var isBluetoothOff: Bool {
        !monitor.isBluetoothEnabled
    }
    
    init(monitor: BluetoothMonitor) {
        self.monitor = monitor
    }
}

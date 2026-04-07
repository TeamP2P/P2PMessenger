//
//  WelcomeScreenVM.swift
//  P2PMessenger
//
//  Created by Иван Иванов on 01.04.2026.
//

import Observation
import Foundation

@MainActor
@Observable
final class WelcomeScreenVM {

    let benefitsSectionContent: [BenefitItem] = [
        BenefitItem(title: "Найдите людей рядом", icon: "1.circle"),
        BenefitItem(title: "Отправьте запрос на чат", icon: "2.circle"),
        BenefitItem(title: "Общайтесь в личных и общих чатах", icon: "3.circle")
    ]

    private let permissionManager: PermissionManager

    var userName: String = UserDefaults.standard.string(forKey: MPCNetworkConstants.userDefaultsDisplayNameKey) ?? "" {
        didSet {
            UserDefaults.standard.set(userName, forKey: MPCNetworkConstants.userDefaultsDisplayNameKey)
        }
    }

    init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
    }

    var permissions: [PermissionItem] {
        [
            PermissionItem(id: .bluetooth, title: "Bluetooth", icon: "dot.radiowaves.left.and.right", state: permissionManager.bluetoothState),
            PermissionItem(id: .localNetwork, title: "Локальная сеть", icon: "wifi", state: permissionManager.localNetworkState),
            PermissionItem(id: .notifications, title: "Уведомления", icon: "bell.badge", state: permissionManager.notificationsState)
        ]
    }

    var canGoForward: Bool {
        permissions.allSatisfy { $0.state == .granted } && !userName.isEmpty
    }

    func requestPermission(type: PermissionType) {
        switch type {
        case .bluetooth:        permissionManager.requestBluetooth()
        case .localNetwork:     permissionManager.requestLocalNetwork()
        case .nearbyDiscovery:  permissionManager.requestNearbyDiscovery()
        case .notifications:    permissionManager.requestNotifications()
        }
    }
}

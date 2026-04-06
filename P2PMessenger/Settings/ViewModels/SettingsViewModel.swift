//
//  SettingsViewModel.swift
//  P2PMessenger
//
//  Created by Трофим Чекмарев on 06.04.2026.
//

import SwiftUI

@Observable
final class SettingsViewModel {
    var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: MPCNetworkConstants.userDefaultsDisplayNameKey)
        }
    }

    init() {
        self.userName = UserDefaults.standard.string(forKey: MPCNetworkConstants.userDefaultsDisplayNameKey) ?? ""
    }
}

//
//  SettingsViewModel.swift
//  P2PMessenger
//
//  Created by Трофим Чекмарев on 06.04.2026.
//

import SwiftUI

@Observable
final class SettingsViewModel {
    var spaceTaken: Int
    var progress: Double
    var visibilityToggle: Bool
    var requestToggle: Bool
    var networkToggle: Bool
    
    var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: MPCNetworkConstants.userDefaultsDisplayNameKey)
        }
    }

    init(spaceTaken: Int = 1234,
         progress: Double = 0.67,
         visibilityToggle: Bool = false,
         requestToggle: Bool = false,
         networkToggle: Bool = false) {
        self.spaceTaken = spaceTaken
        self.progress = progress
        self.visibilityToggle = visibilityToggle
        self.requestToggle = requestToggle
        self.networkToggle = networkToggle
        self.userName = UserDefaults.standard.string(forKey: MPCNetworkConstants.userDefaultsDisplayNameKey) ?? ""
    }
}

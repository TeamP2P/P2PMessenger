//
//  DependencyContainer.swift
//  P2PMessenger
//
//  Created by Maksim on 03.04.2026.
//

import Foundation
import Observation

@Observable
final class DependencyContainer {
    @ObservationIgnored
    let notificationService: NotificationServiceProtocol
    @ObservationIgnored
    let router: AppRouter
    @ObservationIgnored
    let networkService: MPCNetworkService
    
    
    @MainActor
    init(notificationService: NotificationServiceProtocol = NotificationService(),
         router: AppRouter = AppRouter(),
         networkService: MPCNetworkService = MPCNetworkService()) {
        self.notificationService = notificationService
        self.router = router
        self.networkService = networkService
    }
}

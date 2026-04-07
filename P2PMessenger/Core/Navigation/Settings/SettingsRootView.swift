//
//  SettingsRootView.swift
//  P2PMessenger
//
//  Created by Иван Иванов on 02.04.2026.
//
import SwiftUI

struct SettingsRootView: View { 
    @Bindable private var viewModel: SettingsViewModel
    
    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
            SettingsView(viewModel: viewModel)
                .navigationTitle("Настройки")
    }
}

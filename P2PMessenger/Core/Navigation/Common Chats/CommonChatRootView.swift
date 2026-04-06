//
//  CommonChatRootView.swift
//  P2PMessenger
//
//  Created by Иван Иванов on 02.04.2026.
//
import SwiftUI
import Observation

struct CommonChatRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: CommonChatViewModel

    init(chatViewModel: ChatViewModel) {
        _viewModel = State(initialValue: CommonChatViewModel(chatViewModel: chatViewModel))
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        ChatScreenView(
            viewModel: bindableViewModel.screenViewModel,
            draftMessage: $bindableViewModel.draftMessage,
            onSend: bindableViewModel.sendMessage
        )
        .onAppear {
            bindableViewModel.startIfNeeded()
        }
        .onChange(of: scenePhase) { _, newValue in
            bindableViewModel.handleScenePhase(newValue)
        }
    }
}

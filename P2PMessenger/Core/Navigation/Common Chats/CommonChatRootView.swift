//
//  CommonChatRootView.swift
//  P2PMessenger
//
//  Created by Иван Иванов on 02.04.2026.
//
import SwiftUI

struct CommonChatRootView: View {
    let viewModel: ChatScreenViewModel

    var body: some View {
        ChatScreenView(
            viewModel: viewModel,
            draftMessage: .constant("")
        )
    }
}

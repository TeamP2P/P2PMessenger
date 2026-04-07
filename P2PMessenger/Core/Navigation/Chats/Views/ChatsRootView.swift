//
//  ChatsRootView.swift
//  P2PMessenger
//
//  Created by Иван Иванов on 02.04.2026.
//
import SwiftUI

struct ChatsRootView: View {
    private let viewModel: ChatsRootViewModel
    @Bindable private var router: ChatsRouter

    init(viewModel: ChatsRootViewModel, router: ChatsRouter) {
        self.viewModel = viewModel
        self.router = router
    }
    
    var body: some View {
        NavigationStack(path: $router.path) {
            ChatsListView(
                viewModel: viewModel.chatListViewModel,
                plusButtonAction: {router.push(.searchDialog)},
                chatRowButtonAction: {router.push(.addDialog)}
            )
            .navigationDestination(for: ChatsRoute.self) { route in
                switch route {
                case .dialog:
                    ChatScreenView(viewModel: viewModel.chatScreenViewModel,
                                   draftMessage: .constant(""), onBack: router.popToRoot)
                    .navigationBarBackButtonHidden(true)
                    
                    
                case .searchDialog:
                    VStack(spacing: 16) {
                        NearbyUsersView(viewModel: viewModel.nearbyUserViewModel,
                                        onUserButtonTap: {router.push(.addDialog)})
                    }
                    .navigationTitle("Люди рядом")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .tabBar)
                    // AddDialogView()
                case .addDialog:
                    ChatScreenView(viewModel: viewModel.chatScreenViewModel,
                                   draftMessage: .constant(""), onBack: router.popToRoot)
                    .navigationBarBackButtonHidden(true)
                    
                    
                    
                }
            }
        }
        .toolbar(router.path.isEmpty ? .visible : .hidden, for: .tabBar)
    }
}

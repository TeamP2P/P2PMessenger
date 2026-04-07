//
//  NearbyUsersView.swift
//  P2PMessenger
//
//  Created by Трофим Чекмарев on 03.04.2026.
//

import SwiftUI

struct NearbyUsersView: View {
    let viewModel: NearbyUserViewModel
    let onUserButtonTap: () -> Void

    init(viewModel: NearbyUserViewModel, onUserButtonTap: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onUserButtonTap = onUserButtonTap
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                discoveryStatusCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                sectionHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                usersList
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(Color("P2PLightGray"))
    }

    // MARK: - Discovery Status Card

    private var discoveryStatusCard: some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color("P2PLightGray"))
                    .frame(width: 40, height: 40)

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 18))
                    .foregroundStyle(Color("P2PDarkGray"))
            }
            .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "nearby_users_scanning_title"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color("P2PBlack"))

                Text(String(localized: "nearby_users_scanning_subtitle"))
                    .font(.system(size: 12))
                    .foregroundStyle(Color("P2PDarkGray"))
            }
            .padding(.leading, 12)

            Spacer()

            if viewModel.isScanning {
                ScanningDotsView()
                    .padding(.trailing, 16)
            }
        }
        .frame(height: 74)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("P2PLightGray"), lineWidth: 1)
        )
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        Text(String(format: String(localized: "nearby_users_found_count"), viewModel.users.count))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color("P2PDarkGray"))
            .kerning(0.48)
    }

    // MARK: - Users List

    private var usersList: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.users) { user in
                NearbyUserRowView(user: user, onTap: onUserButtonTap)
            }
        }
    }
}

// MARK: - Scanning Dots

private struct ScanningDotsView: View {
    @State private var activeDot: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color("P2PDarkGray"))
                    .frame(width: 5, height: 5)
                    .opacity(activeDot == index ? 1.0 : 0.32)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeInOut(duration: 0.2)) {
                    activeDot = (activeDot + 1) % 3
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        NearbyUsersView(
            viewModel: NearbyUserViewModel(
                coordinator: PeerSessionCoordinator(networkService: MPCNetworkService())
            ),
            onUserButtonTap: {}
        )
    }
}
#endif

//
//  WelcomeScreen.swift
//  P2PMessenger
//
//  Created by Иван Иванов on 01.04.2026.
//

import SwiftUI

struct WelcomeScreenView: View {
    @Bindable var vm: WelcomeScreenVM

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                headerSection
                howItWorksSection
                permissionsSection
                nameSection
                buttonSection
                Spacer().frame(height: 20)
            }
            .padding()
        }
        .onAppear {
            vm.syncDisplayName()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .padding(.top, 20)
            Text("welcomeToP2PMessenger")
                .font(.headline)
                .bold()
                .foregroundStyle(.p2PBlack)
                .padding(.bottom, 10)
            Text("noInternetMessaging")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.p2PDarkGray)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
        }
    }

    private var howItWorksSection: some View {
        VStack(spacing: 10) {
            Text("howItWorks")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.p2PDarkGray)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(vm.benefitsSectionContent) { benefit in
                BenefitRow(title: benefit.title, icon: benefit.icon)
            }
        }
    }

    private var permissionsSection: some View {
        VStack(spacing: 10) {
            Text("permissions")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.p2PDarkGray)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(vm.permissions) { permission in
                PermissionRow(permission: permission) {
                    vm.requestPermission(type: permission.id)
                }
            }
        }
    }

    private var nameSection: some View {
        VStack(spacing: 10) {
            Text("yourName")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.p2PDarkGray)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("enterYourName", text: $vm.userName)
                .accessibilityIdentifier("welcome_username_textfield")
                .frame(height: 60)
                .accentColor(.p2PBlack)
                .padding(.leading)
                .background(.p2PLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var buttonSection: some View {
        Button(
            action: {
                vm.setOnboardingPassed()
            },
            label: {
                Text("letsStart")
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(vm.canGoForward ? .white : .p2PBlack)
                    .padding(.horizontal)
                    .background(vm.canGoForward ? .p2PBlack : .p2PLightGray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top)
            }
        )
        .disabled(!vm.canGoForward)
        .accessibilityIdentifier("welcome_start_button")
    }
}

private struct WelcomeCardRow<Trailing: View>: View {
    let title: String
    let icon: String
    let iconSize: CGFloat
    @ViewBuilder let trailing: Trailing

    init(
        title: String,
        icon: String,
        iconSize: CGFloat = 15,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.icon = icon
        self.iconSize = iconSize
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.p2PDarkBlue)
            Spacer()
            trailing
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(.p2PLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct BenefitRow: View {
    let title: String
    let icon: String

    var body: some View {
        WelcomeCardRow(title: title, icon: icon) {
            Image(systemName: "checkmark")
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .foregroundStyle(.p2PDarkGray)
        }
    }
}

private struct PermissionRow: View {
    let permission: PermissionItem
    let onRequest: () -> Void

    var body: some View {
        WelcomeCardRow(title: permission.title, icon: permission.icon) {
            if permission.state == .granted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                    Text("allowed")
                }
                .foregroundStyle(.p2PDarkGray)
            } else {
                Button(action: onRequest) {
                    Text("allow")
                        .frame(height: 29)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                        .background(.p2PBlack)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    let storage = AppProfileStorage(storage: AppKeyValueStorage(defaults: .standard))
    let provider = LocalPeerIdentityProvider(profileStorage: storage)
    return WelcomeScreenView(vm: WelcomeScreenVM(
        permissionManager: PermissionManager(notification: NotificationService(), permissionsStorage: PermissionsStorage(storage: AppKeyValueStorage(defaults: .standard))),
        identityProvider: provider,
        onboardingState: OnboardingState(storage: OnboardingStorage(storage: AppKeyValueStorage(defaults: .standard)))
    ))
}
#endif

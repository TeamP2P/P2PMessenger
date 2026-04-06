//
//  SettingsView.swift
//  P2PMessenger
//
//  Created by Дмитрий Филимонов on 01.04.2026.
//

import SwiftUI

struct SettingsView: View {
    @State var visibilityToggle: Bool = false
    @State var requestToggle: Bool = false
    @State var networkToggle: Bool = false
    var username = "иван"
    var spaceTaken = 1234
    @State var progress = 0.67
    @Bindable private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            Section {
                UserCard(username: $viewModel.userName)
                    .tint(.primary)
            } header: {
                Text("profileUpper")
                    .font(.footnote)
            }

            Section {
                Toggle(isOn: $visibilityToggle) {
                    TextCard(label: String(localized: "enableToFindMe"),
                             text: String(localized: "observableByOthers"))
                }
                .tint(Color("P2PDarkBlue"))
                Toggle(isOn: $requestToggle) {
                    TextCard(label: String(localized: "enableRequestsToChat"),
                             text: String(localized: "acceptNewRequests"))
                }
                .tint(Color("P2PDarkBlue"))
            } header: {
                Text("privacyUpper")
                    .font(.footnote)
            }

            Section {
                Toggle(isOn: $networkToggle) {
                    TextCard(label: String(localized: "online"),
                             text: String(localized: "observableInP2Pnetwork"))
                }
                .tint(Color("P2PDarkBlue"))
            } header: {
                Text("networkUpper")
                    .font(.footnote)
            }

            Section {
                StorageCard(size: spaceTaken, progress: $progress)
            } header: {
                Text("dataUpper")
                    .font(.footnote)
            }

            Section {
                Button {

                } label: {
                    DeleteCard()
                }
            }

            Section {} footer: {
                Text("appNameAndVersion")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
}

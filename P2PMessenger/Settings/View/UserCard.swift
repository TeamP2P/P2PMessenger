//
//  UserCard.swift
//  P2PMessenger
//
//  Created by Дмитрий Филимонов on 02.04.2026.
//

import SwiftUI

struct UserCard: View {
    @Binding var username: String

    var body: some View {
        HStack {
            Circle()
                .fill(.secondary)
                .stroke(Color.black, lineWidth: Constants.userAvatarStrokeWidth)
                .frame(width: Constants.userAvatarSize, height: Constants.userAvatarSize)
                .opacity(Constants.userAvatarOpacity)
                .overlay {
                    Text(String(username.uppercased().first ?? "?"))
                        .font(.title)
                }
                .padding(.trailing, Constants.userAvatarPadding)

            VStack(alignment: .leading) {
                Text("userName")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.bottom, Constants.userTextPadding)
                TextField("userName", text: $username)
                    .font(.title3)
            }
            Spacer()
        }
        .padding(.vertical, Constants.userCardPadding)
    }
}

private enum Constants {
    static let userAvatarSize: CGFloat = 60
    static let userAvatarStrokeWidth: CGFloat = 0.5
    static let userAvatarOpacity: CGFloat = 0.2
    static let userAvatarPadding: CGFloat = 6
    static let userTextPadding: CGFloat = 2
    static let userCardPadding: CGFloat = 5
}

#Preview {
    Group {
        UserCard(username: .constant("TEST"))
        UserCard(username: .constant("123"))
        UserCard(username: .constant("иван"))
    }
    .padding(8)
}

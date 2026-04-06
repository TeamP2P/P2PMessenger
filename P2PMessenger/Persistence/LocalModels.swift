import Foundation
import SwiftData

@Model
final class LocalUserProfile {
    var id: UUID
    var username: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        username: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.username = username
        self.createdAt = createdAt
    }
}

@Model
final class LocalChat {
    var id: UUID
    var title: String
    var subtitle: String
    var participantName: String?
    var isGroup: Bool
    var isRequest: Bool
    var isOnline: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        participantName: String? = nil,
        isGroup: Bool,
        isRequest: Bool = false,
        isOnline: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.participantName = participantName
        self.isGroup = isGroup
        self.isRequest = isRequest
        self.isOnline = isOnline
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class LocalMessage {
    var id: UUID
    var chatID: UUID
    var senderName: String
    var text: String
    var createdAt: Date
    var isOutgoing: Bool

    init(
        id: UUID = UUID(),
        chatID: UUID,
        senderName: String,
        text: String,
        createdAt: Date = .now,
        isOutgoing: Bool
    ) {
        self.id = id
        self.chatID = chatID
        self.senderName = senderName
        self.text = text
        self.createdAt = createdAt
        self.isOutgoing = isOutgoing
    }
}

import Foundation
import SwiftData

enum AppBootstrapper {
    static let commonChatTitle = "Общий чат"

    static func ensureInitialData(in context: ModelContext, for user: LocalUserProfile) {
        ensureCommonChatExists(in: context)
        ensureDemoDirectChatsExist(in: context, for: user)
    }

    @discardableResult
    static func ensureCommonChatExists(in context: ModelContext) -> LocalChat {
        if let existingChat = findCommonChat(in: context) {
            return existingChat
        }

        let commonChat = LocalChat(
            title: commonChatTitle,
            subtitle: "Локальный групповой чат",
            isGroup: true,
            isRequest: false,
            isOnline: true
        )
        context.insert(commonChat)

        makeCommonChatMessages(for: commonChat).forEach { context.insert($0) }

        try? context.save()
        return commonChat
    }

    static func ensureDemoDirectChatsExist(in context: ModelContext, for user: LocalUserProfile) {
        let existingChats = (try? context.fetch(FetchDescriptor<LocalChat>())) ?? []
        let hasDirectChats = existingChats.contains { !$0.isGroup }
        guard !hasDirectChats else { return }

        demoContacts.enumerated().forEach { index, contact in
            let timestamp = Date.now.addingTimeInterval(TimeInterval(-5000 + index * 500))
            let directChat = LocalChat(
                title: contact.name,
                subtitle: contact.isOnline ? "в сети" : "не в сети",
                participantName: contact.name,
                isGroup: false,
                isRequest: false,
                isOnline: contact.isOnline,
                createdAt: timestamp,
                updatedAt: timestamp
            )
            context.insert(directChat)
            context.insert(makeGreetingMessage(for: directChat, contact: contact, user: user))
        }

        try? context.save()
    }

    static func createDirectChatIfNeeded(with userName: String, in context: ModelContext) -> LocalChat {
        let descriptor = FetchDescriptor<LocalChat>(
            predicate: #Predicate<LocalChat> { chat in
                chat.isGroup == false && chat.title == userName
            }
        )

        if let existingChat = (try? context.fetch(descriptor))?.first {
            return existingChat
        }

        let newChat = LocalChat(
            title: userName,
            subtitle: "новый чат",
            participantName: userName,
            isGroup: false,
            isRequest: true,
            isOnline: true
        )
        context.insert(newChat)
        try? context.save()
        return newChat
    }

    private static let demoContacts: [DemoContact] = [
        DemoContact(name: "Вася", isOnline: true),
        DemoContact(name: "Маша", isOnline: true),
        DemoContact(name: "Глеб", isOnline: false)
    ]

    private static func findCommonChat(in context: ModelContext) -> LocalChat? {
        let descriptor = FetchDescriptor<LocalChat>(
            predicate: #Predicate { $0.isGroup == true && $0.title == commonChatTitle }
        )
        return (try? context.fetch(descriptor))?.first
    }

    private static func makeCommonChatMessages(for chat: LocalChat) -> [LocalMessage] {
        [
            LocalMessage(
                chatID: chat.id,
                senderName: "Вася",
                text: "Всем привет! Это общий оффлайн-чат.",
                createdAt: .now.addingTimeInterval(-3600),
                isOutgoing: false
            ),
            LocalMessage(
                chatID: chat.id,
                senderName: "Маша",
                text: "Можно переписываться даже без интернета.",
                createdAt: .now.addingTimeInterval(-3400),
                isOutgoing: false
            )
        ]
    }

    private static func makeGreetingMessage(
        for chat: LocalChat,
        contact: DemoContact,
        user: LocalUserProfile
    ) -> LocalMessage {
        LocalMessage(
            chatID: chat.id,
            senderName: contact.name,
            text: "Привет, \(user.username)! Это локальный чат без бэкенда.",
            createdAt: chat.updatedAt,
            isOutgoing: false
        )
    }
}

private struct DemoContact {
    let name: String
    let isOnline: Bool
}

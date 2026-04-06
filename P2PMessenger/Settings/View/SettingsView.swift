import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [LocalUserProfile]
    @Query private var chats: [LocalChat]
    @Query private var messages: [LocalMessage]

    @AppStorage("settings.visibility") private var isVisibleForNearbyUsers = true
    @AppStorage("settings.requests") private var acceptsChatRequests = true
    @AppStorage("settings.network") private var isOnlineInNetwork = true

    @State private var storageProgress: Double = 0
    @State private var isEditingProfile = false
    @State private var editedUsername = ""

    private var username: String {
        users.first?.username ?? "Пользователь"
    }

    private var estimatedStorageSize: Int {
        let totalCharacters = messages.reduce(0) { partialResult, message in
            partialResult + message.text.count
        }
        return max(1, totalCharacters / 10)
    }

    var body: some View {
        List {
            profileSection
            privacySection
            networkSection
            storageSection
            clearChatsSection
            resetProfileSection

            Section {
            } footer: {
                Text("P2P Messenger ⋅ offline demo")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onAppear(perform: updateStorageProgress)
        .onChange(of: messages.count) {
            updateStorageProgress()
        }
        .onChange(of: isOnlineInNetwork) {
            updateChatsOnlineState()
        }
        .sheet(isPresented: $isEditingProfile) {
            editProfileSheet
        }
    }

    private var profileSection: some View {
        Section {
            Button {
                editedUsername = username
                isEditingProfile = true
            } label: {
                UserCard(username: username)
                    .tint(.primary)
            }
            .buttonStyle(.plain)
        } header: {
            Text("ПРОФИЛЬ")
                .font(.footnote)
        }
    }

    private var privacySection: some View {
        Section {
            Toggle(isOn: $isVisibleForNearbyUsers) {
                TextCard(label: "Разрешить находить меня", text: "Виден пользователям рядом")
            }
            .tint(Color("P2PDarkBlue"))

            Toggle(isOn: $acceptsChatRequests) {
                TextCard(label: "Разрешить запросы на переписку", text: "Принимать новые запросы")
            }
            .tint(Color("P2PDarkBlue"))
        } header: {
            Text("ПРИВАТНОСТЬ")
                .font(.footnote)
        }
    }

    private var networkSection: some View {
        Section {
            Toggle(isOn: $isOnlineInNetwork) {
                TextCard(label: "В сети", text: "Активен в P2P сети")
            }
            .tint(Color("P2PDarkBlue"))
        } header: {
            Text("СЕТЬ")
                .font(.footnote)
        }
    }

    private var storageSection: some View {
        Section {
            StorageCard(size: estimatedStorageSize, progress: $storageProgress)
        } header: {
            Text("ДАННЫЕ")
                .font(.footnote)
        }
    }

    private var clearChatsSection: some View {
        Section {
            Button(action: deleteAllChats) {
                DeleteCard()
            }
        }
    }

    private var resetProfileSection: some View {
        Section {
            Button(role: .destructive, action: resetProfile) {
                Label("Сбросить профиль", systemImage: "person.crop.circle.badge.xmark")
            }
        }
    }

    private var editProfileSheet: some View {
        NavigationStack {
            Form {
                Section("Имя пользователя") {
                    TextField("Введите имя", text: $editedUsername)
                }
            }
            .navigationTitle("Профиль")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isEditingProfile = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveProfileName()
                    }
                    .disabled(editedUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func updateStorageProgress() {
        storageProgress = min(max(Double(estimatedStorageSize) / 500, 0.02), 1.0)
    }

    private func updateChatsOnlineState() {
        chats
            .filter { !$0.isGroup }
            .forEach { chat in
                chat.isOnline = isOnlineInNetwork
                chat.subtitle = isOnlineInNetwork ? "в сети" : "не в сети"
            }

        try? modelContext.save()
    }

    private func saveProfileName() {
        let trimmedName = editedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        users.first?.username = trimmedName
        try? modelContext.save()
        isEditingProfile = false
    }

    private func deleteAllChats() {
        messages.forEach { modelContext.delete($0) }
        chats.forEach { modelContext.delete($0) }

        if let user = users.first {
            AppBootstrapper.ensureInitialData(in: modelContext, for: user)
        }

        try? modelContext.save()
        updateStorageProgress()
    }

    private func resetProfile() {
        messages.forEach { modelContext.delete($0) }
        chats.forEach { modelContext.delete($0) }
        users.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [LocalUserProfile.self, LocalChat.self, LocalMessage.self], inMemory: true)
}

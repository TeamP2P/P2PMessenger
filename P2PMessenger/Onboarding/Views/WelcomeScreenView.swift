import SwiftUI
import SwiftData

struct WelcomeScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WelcomeScreenVM()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                headerSection
                howItWorksSection
                permissionsSection
                nameSection
                continueButtonSection
                Spacer()
                    .frame(height: 20)
            }
            .padding()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .padding(.top, 20)

            Text("Добро пожаловать в P2P Messenger")
                .font(.headline)
                .bold()
                .foregroundStyle(.p2PBlack)
                .padding(.bottom, 10)

            Text("Общайтесь напрямую с людьми рядом без интернета")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.p2PDarkGray)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
        }
    }

    private var howItWorksSection: some View {
        VStack(spacing: 10) {
            sectionTitle("Как это работает")

            ForEach(viewModel.benefitsSectionContent) { benefit in
                BenefitRow(title: benefit.title, icon: benefit.icon)
            }
        }
    }

    private var permissionsSection: some View {
        VStack(spacing: 10) {
            sectionTitle("Разрешения")

            ForEach(viewModel.permissions) { permission in
                PermissionRow(permission: permission) {
                    viewModel.requestPermission(type: permission.id)
                }
            }
        }
    }

    private var nameSection: some View {
        VStack(spacing: 10) {
            sectionTitle("Ваше имя")

            TextField("Введите имя", text: $viewModel.userName)
                .frame(height: 60)
                .accentColor(.p2PBlack)
                .padding(.leading)
                .background(.p2PLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Имя увидят другие пользователи поблизости.")
                .font(.footnote)
                .foregroundStyle(.p2PTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var continueButtonSection: some View {
        VStack(spacing: 6) {
            Button(action: registerLocally) {
                Text("Начнём!")
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(viewModel.canGoForward ? .white : .p2PBlack)
                    .padding(.horizontal)
                    .background(viewModel.canGoForward ? .p2PBlack : .gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top)
            }
            .disabled(!viewModel.canGoForward)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .fontWeight(.medium)
            .foregroundStyle(.p2PDarkGray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func registerLocally() {
        let trimmedName = viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let existingProfiles = (try? modelContext.fetch(FetchDescriptor<LocalUserProfile>())) ?? []
        existingProfiles.forEach { modelContext.delete($0) }

        let profile = LocalUserProfile(username: trimmedName)
        modelContext.insert(profile)
        AppBootstrapper.ensureInitialData(in: modelContext, for: profile)

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save profile: \(error)")
        }
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
        .background(.gray.opacity(0.1))
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
        HStack {
            Image(systemName: permission.icon)
            Text(permission.title)
            Spacer()

            if permission.state == .granted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                    Text("Разрешено")
                }
                .foregroundStyle(.p2PDarkGray)
            } else {
                Button(action: onRequest) {
                    Text("Разрешить")
                        .frame(height: 29)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                        .background(.p2PBlack)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
#Preview {
    WelcomeScreenView()
        .modelContainer(for: [LocalUserProfile.self, LocalChat.self, LocalMessage.self], inMemory: true)
}
#endif

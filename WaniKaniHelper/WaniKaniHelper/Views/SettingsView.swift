// Every setting the app has, grouped by what it affects. Reached from the Home screen so the
// dashboard stays focused on reviews and lessons rather than configuration.
import SwiftUI

struct SettingsView: View {
    let user: WKUserData
    let store: SubjectStore
    var onApiKeyUpdated: (String, WKUserData) -> Void = { _, _ in }
    var onSignOut: () -> Void = {}

    @AppStorage(ReviewSettings.easyModeKey) private var easyMode = false
    @State private var showEditAPIKey = false
    @State private var showSignOutConfirm = false

    var body: some View {
        List {
            Section("Reviews") {
                Toggle(isOn: $easyMode) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("WKTeal").opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(Color("WKTeal"))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Easy Mode")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("Meaning-only reviews. Readings auto-pass, so SRS still advances.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Example Sentences") {
                NavigationLink {
                    AIModelSetupView()
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.indigo.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "cpu")
                                    .foregroundStyle(Color.indigo)
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("AI Model")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                            Text(AIModelManager.shared.activeBackendName)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Account") {
                Button {
                    showEditAPIKey = true
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("WKPlum").opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(Color("WKPlum"))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        Text("Edit API Key")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                syncRow

                signOutRow
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign out of WaniKani?", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) { signOut() }
        } message: {
            Text("Your API token is removed from this device. Downloaded subjects and kana progress are kept, and nothing changes on WaniKani.")
        }
        .fullScreenCover(isPresented: $showEditAPIKey) {
            AuthView { newKey, newUser in
                onApiKeyUpdated(newKey, newUser)
                showEditAPIKey = false
            } onCancel: {
                showEditAPIKey = false
            }
        }
    }

    // MARK: - Account rows

    private var syncRow: some View {
        Button {
            Task { await store.syncSubjects(force: true) }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("WKGold").opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                            .foregroundStyle(Color("WKGold"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sync Subjects")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(syncSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(store.syncError == nil ? Color.secondary : Color.red)
                }
                Spacer()
                if store.isSyncing {
                    ProgressView()
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isSyncing)
    }

    private var signOutRow: some View {
        Button(role: .destructive) {
            showSignOutConfirm = true
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                            .font(.system(size: 15, weight: .semibold))
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                    Text(user.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // Levels and subject content are refreshed automatically once a day; this line tells the
    // user where that stands, since a stale sync is otherwise invisible.
    private var syncSubtitle: String {
        if store.isSyncing { return "Syncing…" }
        if let error = store.syncError { return error }
        guard let last = store.lastSyncDate else { return "Never synced" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Updated " + formatter.localizedString(for: last, relativeTo: Date())
    }

    // Clears this device's link to the WaniKani account. The subject cache and kana SRS entries
    // survive: they're generic content and local practice data, not credentials.
    private func signOut() {
        KeychainService.delete()
        UserDefaults.standard.removeObject(forKey: "cachedUser")
        WidgetWordSync.clear()
        onSignOut()
    }
}

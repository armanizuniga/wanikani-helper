// This view is the first screen shown to users who have not yet authenticated.
// Displays the app logo and name, accepts a WaniKani API key, validates it against
// the WaniKani API, and calls back with the key and user data on success.
import SwiftUI

struct AuthView: View {
    let onAuthenticated: (String, WKUserData) -> Void

    @State private var apiKey: String = ""
    @State private var isLoading: Bool = false
    @State private var error: String?
    @State private var showingTokenInfo = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 40) // ← adjust to shift closer/further from Dynamic Island

            VStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(spacing: 6) {
                    Text("Fuyu")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .tracking(-0.5)
                    Text("A WaniKani Assistant")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(" API Token")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("AccentPink"))
                    Button {
                        showingTokenInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color("AccentPink"))
                    }
                    .buttonStyle(.plain)
                }

                Text(" Find your token at wanikani.com → Settings → API Tokens")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color("AccentPink"))

                ZStack(alignment: .leading) {
                    if apiKey.isEmpty {
                        Text("Paste your WaniKani API token")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color("AccentPink"))
                    }
                    SecureField("", text: $apiKey)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.primary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(12)
                .background(Color("AccentPink").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if let error {
                    Text(error)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.red)
                }
            }

            VStack(spacing: 12) {
                Button {
                    Task { await authenticate() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Label("Connect Account", systemImage: "play.fill")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 22)
                    .padding(.horizontal, 16)
                    .background(apiKey.isEmpty ? Color("WKTeal").opacity(0.45) : Color("WKTeal"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(DepthButtonStyle(depth: apiKey.isEmpty ? 0 : 5, depthColor: Color("WKTealDeep")))
                .disabled(apiKey.isEmpty || isLoading)

            }

            Spacer()

            Text("API Token stored on device only")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
        }
        .padding()
        .sheet(isPresented: $showingTokenInfo) {
            TokenInfoSheet()
        }
    }

    private func authenticate() async {
        isLoading = true
        error = nil
        await WaniKaniAPIClient.shared.configure(apiKey: apiKey)
        do {
            let user = try await WaniKaniAPIClient.shared.fetchUser()
            onAuthenticated(apiKey, user)
        } catch WaniKaniError.unauthorized {
            error = "Invalid token. Double-check your API key."
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Token info sheet

private struct TokenInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    infoStep(
                        number: "1",
                        title: "Go to WaniKani Settings",
                        detail: "Visit wanikani.com → Account → API Tokens"
                    )

                    infoStep(
                        number: "2",
                        title: "Generate a new token",
                        detail: "Tap \"Generate a new token\" and give it a name like \"Fuyu\"."
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        stepHeader(number: "3", title: "Enable these permissions")
                        permissionRow(name: "assignments:start", note: "Required to start lessons")
                        permissionRow(name: "reviews:create", note: "Required to submit reviews")
                        Text("All read permissions are enabled by default — leave them on.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }

                    infoStep(
                        number: "4",
                        title: "Copy and paste",
                        detail: "Copy the generated token and paste it into the API Token field."
                    )
                }
                .padding(24)
            }
            .navigationTitle("Setting Up Your Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
        }
    }

    private func infoStep(number: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            stepHeader(number: number, title: title)
            Text(detail)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func stepHeader(number: String, title: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color("AccentPink"))
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
        }
    }

    private func permissionRow(name: String, note: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color("WKGreen"))
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                Text(note)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("WKGreen").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

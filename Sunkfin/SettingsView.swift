import SafariServices
import SwiftUI

struct SettingsView: View {
    let onLogout: () -> Void

    @State private var showingLogoutWarning = false
    @State private var showingDonationSheet = false
    @State private var showingSupportResetConfirmation = false
    @ObservedObject private var supporterManager = SupporterManager.shared
    private let downloadManager = DownloadManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingDonationSheet = true
                    } label: {
                        Text("Support Sunkfin via a small donation")
                    }

                    if supporterManager.isSupporterActive, let expiryText = supporterManager.expiryDisplayText {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Thanks for your support")
                                .font(.subheadline)
                            Button {
                                showingSupportResetConfirmation = true
                            } label: {
                                Text("Donor benefits available until \(expiryText). Tap to reset")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                Section {
                    Text("Sunkfin is not endorsed, supported, or built in collaboration with the Jellyfin core team. It is offered as-is and donations are appreciated.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        showingLogoutWarning = true
                    } label: {
                        Text("Log out")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingLogoutWarning, onDismiss: {
                showingLogoutWarning = false
            }) {
                LogoutConfirmationView {
                    performLogout()
        showingLogoutWarning = false
    }
            }
            .sheet(isPresented: $showingDonationSheet) {
                SafariView(url: URL(string: "https://go.jackcrane.rocks/sunkfin-donation")!)
            }
            .alert("Reset donor benefits", isPresented: $showingSupportResetConfirmation) {
                Button("Reset", role: .destructive) {
                    supporterManager.clearSupporter()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove your donor status.")
            }
        }
    }

    private func performLogout() {
        downloadManager.removeAllDownloads()
        UserDefaults.standard.removeObject(forKey: "accessToken")
        UserDefaults.standard.removeObject(forKey: "serverUrl")
        UserDefaults.standard.removeObject(forKey: "userId")
        onLogout()
    }
}

private struct LogoutConfirmationView: View {
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)

                Text("Warning: You are about to log out of Sunkfin on your device. Continuing will clear your credentials from your device, unset the server location, and delete any downloaded content.")
                    .font(.body)

                Spacer()

                Button(role: .destructive) {
                    onContinue()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                }
            }
            .padding()
            .navigationTitle("Warning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

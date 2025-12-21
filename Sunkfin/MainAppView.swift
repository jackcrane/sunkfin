//
//  MainAppView.swift
//  Sunkfin
//
//  Created by Jack Crane on 3/12/25.
//

import SafariServices
import SwiftUI

struct MainAppView: View {
    let serverUrl: String
    let onLogout: () -> Void
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var showDonationSheet = false
    @State private var hasPresentedDonationSheet = false
    private let donationThresholdBytes: Int64 = 10 * 1024 * 1024 * 1024

    var body: some View {
        TabView {
            ShowsListView(serverUrl: serverUrl)
                .tabItem {
                    Label("Library Items", systemImage: "movieclapper")
                }

            DownloadedMediaListView(serverUrl: serverUrl)
                .tabItem {
                    Label {
                        Text("Downloads")
                    } icon: {
                        DownloadTabIcon(isDownloading: downloadManager.hasActiveDownloads)
                    }
                }

            SettingsView(onLogout: onLogout)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear(perform: checkDonationSheet)
        .sheet(isPresented: $showDonationSheet) {
            DonationPrompt(isPresented: $showDonationSheet)
        }
    }

    private func checkDonationSheet() {
        guard !hasPresentedDonationSheet else { return }
        if downloadManager.totalDownloadedBytes >= donationThresholdBytes {
            hasPresentedDonationSheet = true
            showDonationSheet = true
        }
    }

}

#Preview {
    MainAppView(serverUrl: "https://stream.jackcrane.rocks", onLogout: {})
        .onAppear {
            UserDefaults.standard.setValue("8c13cb1bb33549548979709e1734681f", forKey: "accessToken")
        }
}

private struct DownloadTabIcon: View {
    let isDownloading: Bool

    var body: some View {
        Image(systemName: "square.and.arrow.down")
            .symbolEffect(.wiggle, options: .speed(0.7), isActive: isDownloading)
    }
}

private struct DonationPrompt: View {
    @Binding var isPresented: Bool
    @State private var showSafari = false

    private let donationMessage = """
Hey superuser! It looks like you have been enjoying Sunkfin. \
This is a free app built in my free time. If you feel so inclined, \
small (or large 😉) donations are massively appreciated.
"""
    private let donationURL = URL(string: "https://go.jackcrane.rocks/sunkfin-donation")

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("😎")
                .font(.system(size: 56))

            Text(donationMessage)
                .multilineTextAlignment(.leading)
                .font(.body)

            Text("You are seeing this message because you have over 10 GB of content downloaded. You are not required to donate, but doing so will contribute to the future development of Sunkfin and will prevent this message from appearing again.")
                .font(.footnote)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 12) {
                donationButton(title: "Donate", background: Color.blue) {
                    if donationURL != nil {
                        showSafari = true
                    }
                }

                donationButton(title: "No Thanks", background: Color.gray.opacity(0.6)) {
                    isPresented = false
                }
            }
        }
        .padding()
        .frame(maxHeight: .infinity)
        .sheet(isPresented: $showSafari) {
            if let url = donationURL {
                SafariView(url: url)
            }
        }
    }

    private func donationButton(title: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(background)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.headline)
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

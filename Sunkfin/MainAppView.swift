//
//  MainAppView.swift
//  Sunkfin
//
//  Created by Jack Crane on 3/12/25.
//

import SwiftUI

struct MainAppView: View {
    let serverUrl: String
    let onLogout: () -> Void
    @StateObject private var downloadManager = DownloadManager.shared
    
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

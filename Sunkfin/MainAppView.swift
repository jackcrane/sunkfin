//
//  MainAppView.swift
//  Sunkfin
//
//  Created by Jack Crane on 3/12/25.
//

import SwiftUI

struct MainAppView: View {
    let serverUrl: String
    
    var body: some View {
        TabView {
            ShowsListView(serverUrl: serverUrl)
                .tabItem {
                    Label("Library Items", systemImage: "movieclapper")
                }
            
            DownloadedMediaListView(serverUrl: serverUrl)
                .tabItem {
                    Label("Downloads", systemImage: "square.and.arrow.down")
                }
            
            Text("Coming Soon")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainAppView(serverUrl: "https://stream.jackcrane.rocks")
        .onAppear {
            UserDefaults.standard.setValue("8c13cb1bb33549548979709e1734681f", forKey: "accessToken")
        }
}

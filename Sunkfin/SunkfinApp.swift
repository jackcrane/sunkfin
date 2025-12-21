//
//  SunkfinApp.swift
//  Sunkfin
//
//  Created by Jack Crane on 3/12/25.
//

import Foundation
import SwiftUI

final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published private(set) var lastURL: URL?

    func handle(_ url: URL) {
        lastURL = url
        handleSupportLink(url)
    }

    private func handleSupportLink(_ url: URL) {
        guard url.scheme == "sunkfin" else { return }
        let pathComponent = (url.host ?? url.path).lowercased()
        guard pathComponent.contains("donate") else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let expValue = components.queryItems?.first(where: { $0.name == "exp" })?.value,
              let timestamp = Double(expValue) else { return }
        let expiryDate = Date(timeIntervalSince1970: timestamp)
        SupporterManager.shared.setSupporter(expiry: expiryDate)
    }

    func clear() {
        lastURL = nil
    }
}

@main
struct SunkfinApp: App {
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handle(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    deepLinkManager.handle(url)
                }
        }
    }
}

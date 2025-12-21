import SwiftUI
import JellyfinAPI
import AVFoundation

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var serverUrl: String?
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @State private var showDeepLinkAlert = false
    @State private var deepLinkMessage: String?

    init() {
        do {
          // Set the audio session category to playback so audio plays even when the ringer is off.
          try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
          try AVAudioSession.sharedInstance().setActive(true)
        } catch {
          print("Audio session setup failed: \(error)")
        }
      }

    var body: some View {
        Group {
            if isLoggedIn, let serverUrl = serverUrl {
                MainAppView(serverUrl: serverUrl, onLogout: handleLogout)
            } else {
                ConnectionView(onLoginSuccess: { url in
                    self.serverUrl = url
                    self.isLoggedIn = true
                })
            }
        }
        .onAppear {
            checkStoredLogin()
        }
        .onChange(of: deepLinkManager.lastURL) { newURL in
            guard let url = newURL, isDonateURL(url) else { return }
            deepLinkMessage = "Thank you for your support. I couldn't keep developing Sunkfin without your support."
            showDeepLinkAlert = true
        }
        .alert("Thank you for your support", isPresented: $showDeepLinkAlert) {
            Button("OK") {
                deepLinkManager.clear()
            }
        } message: {
            Text(deepLinkMessage ?? "")
        }
    }

    private func isDonateURL(_ url: URL) -> Bool {
        let target = (url.host ?? url.path).lowercased()
        return target.contains("donate")
    }

    private func checkStoredLogin() {
        if let savedUrl = UserDefaults.standard.string(forKey: "serverUrl"),
           let token = UserDefaults.standard.string(forKey: "accessToken"),
           !token.isEmpty {
            DispatchQueue.main.async {
                self.serverUrl = savedUrl
                self.isLoggedIn = true
            }
        }
    }

    private func handleLogout() {
        serverUrl = nil
        isLoggedIn = false
    }
}

#Preview {
    ContentView()
}

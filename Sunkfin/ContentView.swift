import SwiftUI
import JellyfinAPI
import AVFoundation

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var serverUrl: String?
    
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
                MainAppView(serverUrl: serverUrl)
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
}

#Preview {
    ContentView()
}

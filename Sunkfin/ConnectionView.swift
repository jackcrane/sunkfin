import SwiftUI
import JellyfinAPI

struct ConnectionView: View {
    var onLoginSuccess: (String) -> Void

    @State private var serverUrl: String = UserDefaults.standard.string(forKey: "serverUrl") ?? ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var navigateToLogin = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connect to Jellyfin")
                    .font(.largeTitle)
                    .bold()

                Text("Enter your server address to continue")
                    .font(.body)
                    .foregroundColor(.gray)
                
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Address")
                        .font(.headline)

                    TextField("https://your-jellyfin-server.com", text: $serverUrl)
                        .padding()
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                        .transition(.opacity)
                }

                Button(action: testConnection) {
                    if isConnecting {
                        ProgressView()
                    } else {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .font(.headline)
                    }
                }
                .disabled(isConnecting)

            }
            .padding()
            .navigationDestination(isPresented: $navigateToLogin) {
                LoginView(serverUrl: serverUrl, onLoginSuccess: onLoginSuccess)
            }
        }
    }

    private func testConnection() {
        guard let url = URL(string: serverUrl), !serverUrl.isEmpty else {
            withAnimation {
                errorMessage = "Invalid URL"
            }
            return
        }

        isConnecting = true
        errorMessage = nil

        Task {
            do {
                let config = JellyfinClient.Configuration(url: url, client: "Sunkfin", deviceName: UIDevice.current.name, deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "", version: "1.0.0")
                let client = JellyfinClient(configuration: config)
                let _ = try await client.send(Paths.getPublicSystemInfo)

                UserDefaults.standard.set(serverUrl, forKey: "serverUrl")
                withAnimation {
                    navigateToLogin = true
                }
            } catch {
                withAnimation {
                    errorMessage = "Failed to connect. Check the URL."
                }
            }
            isConnecting = false
        }
    }
}

#Preview {
    ConnectionView(onLoginSuccess: { _ in })
}

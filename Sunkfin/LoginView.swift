import SwiftUI
import JellyfinAPI

struct LoginView: View {
    let serverUrl: String
    var onLoginSuccess: (String) -> Void

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sign In")
                    .font(.largeTitle)
                    .bold()

                Text("Enter your credentials to access Jellyfin")
                    .font(.body)
                    .foregroundColor(.gray)

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.headline)

                    TextField("Enter username", text: $username)
                        .padding()
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .textInputAutocapitalization(.never)
                        .focused($isInputFocused)

                    Text("Password")
                        .font(.headline)

                    SecureField("Enter password", text: $password)
                        .padding()
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .textInputAutocapitalization(.never)
                        .focused($isInputFocused)
                        .submitLabel(.done)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                        .transition(.opacity)
                }

                Button(action: login) {
                    if isLoggingIn {
                        ProgressView()
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .font(.headline)
                    }
                }
                .disabled(isLoggingIn || username.isEmpty || password.isEmpty)
                .padding(.bottom, isInputFocused ? 10 : 30)
                .animation(.easeInOut, value: isInputFocused)
            }
            .padding()
            .onTapGesture {
                isInputFocused = false
            }
        }
    }

    private func login() {
        isLoggingIn = true
        errorMessage = nil

        Task {
            do {
                let config = JellyfinClient.Configuration(
                    url: URL(string: serverUrl)!,
                    client: "Sunkfin",
                    deviceName: UIDevice.current.name,
                    deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "",
                    version: "1.0.0"
                )
                let client = JellyfinClient(configuration: config)

                let result = try await client.signIn(username: username, password: password)

                // ✅ Persist login credentials
                UserDefaults.standard.set(serverUrl, forKey: "serverUrl")
                UserDefaults.standard.set(result.accessToken, forKey: "accessToken")
                UserDefaults.standard.setValue(result.user?.id, forKey: "userId")

                // ✅ Pass `serverUrl` to `onLoginSuccess`
                DispatchQueue.main.async {
                    onLoginSuccess(serverUrl)
                }
            } catch {
                withAnimation {
                    errorMessage = "Invalid username or password"
                }
            }
            isLoggingIn = false
        }
    }
}

#Preview {
    LoginView(serverUrl: "https://your-jellyfin-server.com", onLoginSuccess: {_ in})
}

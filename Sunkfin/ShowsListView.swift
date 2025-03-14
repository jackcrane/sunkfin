import SwiftUI
import JellyfinAPI

struct ShowsListView: View {
    let serverUrl: String
    @State private var shows: [BaseItemDto] = []
    @State private var searchQuery = ""
    @StateObject private var downloadManager = DownloadManager.shared
    let token = UserDefaults.standard.string(forKey: "accessToken")
    
    var filteredShows: [BaseItemDto] {
        if searchQuery.isEmpty {
            return shows
        } else {
            return shows.filter { $0.name?.localizedCaseInsensitiveContains(searchQuery) == true }
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredShows, id: \.id) { show in
                NavigationLink(destination: LibraryItemView(item: show, serverUrl: serverUrl)) {
                    HStack(spacing: 12) {
                        if let imageUrl = getImageUrl(for: show) {
                            AsyncImage(url: imageUrl) { image in
                                image.resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 80, height: 100)
                            .cornerRadius(8)
                            .clipped()
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(show.name ?? "Unknown Show")
                                .font(.headline)
                                .lineLimit(2)
                            
                            if let year = show.productionYear {
                                Text("\(String(year))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let ticks = show.runTimeTicks {
                                let seconds = ticks / 10000000
                                TimeView(seconds: seconds)
                            }
                            
                            if let userData = show.userData {
                                ShowProgressView(hasWatched: userData.isPlayed ?? false, percentage: userData.playedPercentage)
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(height: 120)
                    .padding(.vertical, 5)
                }
            }
            .searchable(text: $searchQuery, prompt: "Search Library Items")
            .navigationTitle("Library Items")
            .task {
                await fetchShows()
            }
            .refreshable {
                await fetchShows()
            }
        }
    }
    
    private func fetchShows() async {
        guard let url = URL(string: serverUrl),
              let token = UserDefaults.standard.string(forKey: "accessToken") else { return }
        
        let config = JellyfinClient.Configuration(
            url: url,
            client: "Sunkfin",
            deviceName: UIDevice.current.name,
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "",
            version: "1.0.0"
        )
        let client = JellyfinClient(configuration: config, accessToken: token)
        
        do {
            let response = try await client.send(Paths.getItems(
                parameters: Paths.GetItemsParameters(
                    isRecursive: true,
                    includeItemTypes: [
                        BaseItemKind.movie,
//                        BaseItemKind.series
                    ]
                )
            )).value
            shows = response.items ?? []
        } catch {
            print("Failed to fetch shows: \(error)")
        }
    }
    
    private func getImageUrl(for show: BaseItemDto) -> URL? {
        guard let serverUrl = URL(string: serverUrl),
              let id = show.id else { return nil }
        return URL(string: "\(serverUrl)/Items/\(id)/Images/Primary?api_key=\(token ?? "")")
    }
}

struct TimeView: View {
    let seconds: Int

    var formattedTime: String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
            Text(formattedTime)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }
}

struct ShowProgressView: View {
    let hasWatched: Bool
    let percentage: Double?

    var body: some View {
        HStack(spacing: 4) {
            if hasWatched, percentage == nil {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
                Text("Watched")
                    .foregroundColor(.blue)
                    .font(.subheadline)
            } else if let percentage = percentage {
                ProgressView(value: percentage, total: 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 100)
            }
        }
    }
}

#Preview {
    ShowsListView(serverUrl: "https://stream.jackcrane.rocks")
        .onAppear {
            UserDefaults.standard.setValue("8c13cb1bb33549548979709e1734681f", forKey: "accessToken")
        }
}

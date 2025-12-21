import SwiftUI
import JellyfinAPI

struct ShowsListView: View {
    let serverUrl: String
    @State private var shows: [BaseItemDto] = []
    @State private var searchQuery = ""
    @StateObject private var downloadManager = DownloadManager.shared
    let token = UserDefaults.standard.string(forKey: "accessToken")
    @State private var deleteCandidate: DownloadManager.DownloadedItem?
    @State private var showDeleteConfirmation = false
    
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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    switch swipeAction(for: show) {
                    case .delete(let downloaded):
                        Button(role: .destructive) {
                            deleteCandidate = downloaded
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    case .cancel(let itemId):
                        Button(role: .destructive) {
                            downloadManager.cancelDownload(for: itemId)
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle")
                        }
                    case .download:
                        Button {
                            startDownload(for: show)
                        } label: {
                            Label("Download", systemImage: "arrow.down.circle")
                        }
                        .tint(.blue)
                        .disabled(!canStartDownload(for: show))
                    }
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
        .alert("Delete Download", isPresented: $showDeleteConfirmation, presenting: deleteCandidate) { downloaded in
            Button("Delete", role: .destructive) {
                downloadManager.deleteDownloadedItem(for: downloaded.id)
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
        } message: { downloaded in
            Text("Delete \"\(downloaded.baseItem.name ?? "download")\"? This cannot be undone.")
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

    private func startDownload(for show: BaseItemDto) {
        guard let token = token,
              !token.isEmpty,
              let itemId = show.id else {
            return
        }

        guard downloadManager.downloadedItems[itemId] == nil,
              downloadManager.downloads[itemId] == nil else {
            return
        }

        downloadManager.startDownload(for: show, serverUrl: serverUrl, accessToken: token)
    }

    private func canStartDownload(for show: BaseItemDto) -> Bool {
        guard let token = token,
              !token.isEmpty,
              let itemId = show.id else {
            return false
        }

        if downloadManager.downloadedItems[itemId] != nil {
            return false
        }
        if downloadManager.downloads[itemId] != nil {
            return false
        }

        return true
    }

    private func swipeAction(for show: BaseItemDto) -> LibrarySwipeAction {
        guard let itemId = show.id else {
            return .download
        }

        if let downloaded = downloadManager.downloadedItems[itemId] {
            return .delete(downloaded)
        }

        if downloadManager.downloads[itemId] != nil {
            return .cancel(itemId)
        }

        return .download
    }

    private enum LibrarySwipeAction {
        case delete(DownloadManager.DownloadedItem)
        case cancel(String)
        case download
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

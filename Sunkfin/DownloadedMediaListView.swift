import SwiftUI
import AVKit
import JellyfinAPI

struct DownloadedMediaListView: View {
    let serverUrl: String
    @State private var searchQuery = ""
    @StateObject private var downloadManager = DownloadManager.shared

    // Filter downloaded items based on the search query.
    var filteredDownloads: [DownloadManager.DownloadedItem] {
        let items = Array(downloadManager.downloadedItems.values)
        if searchQuery.isEmpty {
            return items
        } else {
            return items.filter { ($0.baseItem.name?.localizedCaseInsensitiveContains(searchQuery) ?? false) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredDownloads, id: \.id) { downloadedItem in
                    NavigationLink(destination: DownloadedMediaDetailView(downloadedItem: downloadedItem, serverUrl: serverUrl)) {
                        HStack(spacing: 12) {
                            // Use the item's primary image (fetched from the server).
                            if let imageUrl = getImageUrl(for: downloadedItem.baseItem) {
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
                                Text(downloadedItem.baseItem.name ?? "Unknown Media")
                                    .font(.headline)
                                    .lineLimit(2)

                                if let year = downloadedItem.baseItem.productionYear {
                                    Text("\(String(year))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                if let ticks = downloadedItem.baseItem.runTimeTicks {
                                    let seconds = ticks / 10000000
                                    TimeView(seconds: seconds)
                                }
                            }
                        }
                        .frame(height: 120)
                        .padding(.vertical, 5)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .searchable(text: $searchQuery, prompt: "Search Downloaded Media")
            .navigationTitle("Downloaded Media")
        }
    }
    
    // Constructs the URL for the item's primary image.
    private func getImageUrl(for item: BaseItemDto) -> URL? {
        guard let id = item.id,
              let token = UserDefaults.standard.string(forKey: "accessToken"),
              let url = URL(string: serverUrl) else { return nil }
        return URL(string: "\(url)/Items/\(id)/Images/Primary?api_key=\(token)")
    }
    
    // Deletes the downloaded item when swiped.
    private func deleteItems(at offsets: IndexSet) {
        offsets.forEach { index in
            let item = filteredDownloads[index]
            downloadManager.deleteDownloadedItem(for: item.id)
        }
    }
}

struct DownloadedMediaDetailView: View {
    let downloadedItem: DownloadManager.DownloadedItem
    let serverUrl: String
    @State private var playbackProgress: Double = 0.0
    @State private var isPlaying: Bool = true

    var body: some View {
        NativeVideoPlayerView(url: downloadedItem.fileURL,
                              startTime: $playbackProgress) { progress in
          let key = "watchProgress_\(downloadedItem.id)"
          UserDefaults.standard.set(progress, forKey: key)
          playbackProgress = progress
        }
        .navigationTitle(downloadedItem.baseItem.name ?? "Media")
        .onAppear {
          let key = "watchProgress_\(downloadedItem.id)"
          playbackProgress = UserDefaults.standard.double(forKey: key)
        }
    }
}

struct NativeVideoPlayerView: UIViewControllerRepresentable {
    let url: URL
    @Binding var startTime: Double
    let onProgressUpdate: (Double) -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // Configure the audio session for playback.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }

        let player = AVPlayer(url: url)
        // Seek to the saved time when the player is created.
        let cmTime = CMTimeMakeWithSeconds(startTime, preferredTimescale: 600)
        player.seek(to: cmTime)

        let controller = AVPlayerViewController()
        controller.player = player
        controller.entersFullScreenWhenPlaybackBegins = true
        controller.exitsFullScreenWhenPlaybackEnds = true

        // Enable Picture-in-Picture (PiP)
        controller.allowsPictureInPicturePlayback = true
        if #available(iOS 14.2, *) {
            controller.canStartPictureInPictureAutomaticallyFromInline = true
        }

        // Set up the coordinator to observe playback progress.
        context.coordinator.player = player
        context.coordinator.addTimeObserver()
        
        // Start playback explicitly.
        player.play()
        
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No dynamic updates needed for now.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onProgressUpdate: onProgressUpdate)
    }

    class Coordinator: NSObject {
        var onProgressUpdate: (Double) -> Void
        var timeObserverToken: Any?
        weak var player: AVPlayer?

        init(onProgressUpdate: @escaping (Double) -> Void) {
            self.onProgressUpdate = onProgressUpdate
        }

        deinit {
            if let token = timeObserverToken, let player = player {
                player.removeTimeObserver(token)
            }
        }

        func addTimeObserver() {
            guard let player = player else { return }
            let interval = CMTimeMakeWithSeconds(1.0, preferredTimescale: 600)
            timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                let seconds = CMTimeGetSeconds(time)
                self?.onProgressUpdate(seconds)
            }
        }
    }
}

#Preview {
    DownloadedMediaListView(serverUrl: "https://yourserverurl.com")
}

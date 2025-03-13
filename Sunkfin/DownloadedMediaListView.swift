import SwiftUI
import MobileVLCKit
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
            List(filteredDownloads, id: \.id) { downloadedItem in
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
}

struct DownloadedMediaDetailView: View {
    let downloadedItem: DownloadManager.DownloadedItem
    let serverUrl: String
    @State private var playbackProgress: Double = 0.0
    @State private var isPlaying: Bool = true

    var body: some View {
        VLCPlayerWithControls(url: downloadedItem.fileURL)
                    .navigationTitle(downloadedItem.baseItem.name ?? "Media")
        .onAppear {
            let key = "watchProgress_\(downloadedItem.id)"
            playbackProgress = UserDefaults.standard.double(forKey: key)
        }
    }
}

import SwiftUI
import MobileVLCKit

struct VLCPlayerView: UIViewRepresentable {
  let url: URL
  @Binding var startTime: Double
  let onProgressUpdate: (Double) -> Void
  @Binding var isPlaying: Bool

  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    let mediaPlayer = VLCMediaPlayer()
    mediaPlayer.drawable = view
    mediaPlayer.delegate = context.coordinator

    let media = VLCMedia(url: url)
    mediaPlayer.media = media

    if isPlaying {
      mediaPlayer.play()
    }

    context.coordinator.mediaPlayer = mediaPlayer
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    guard let mediaPlayer = context.coordinator.mediaPlayer else { return }
    
    // Play or pause as needed.
    if isPlaying {
      if !mediaPlayer.isPlaying {
        mediaPlayer.play()
      }
    } else {
      if mediaPlayer.isPlaying {
        mediaPlayer.pause()
      }
    }
    
    // If the current playback time differs significantly from startTime, seek to new time.
    let currentSeconds = Double(mediaPlayer.time.intValue) / 1000.0
    if abs(currentSeconds - startTime) > 1.0 {
        let ms = Int(startTime * 1000)
        let newVLCTime = VLCTime(number: NSNumber(value: ms))
        mediaPlayer.time = newVLCTime
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onProgressUpdate: onProgressUpdate)
  }

  class Coordinator: NSObject, VLCMediaPlayerDelegate {
    var onProgressUpdate: (Double) -> Void
    var mediaPlayer: VLCMediaPlayer?

    init(onProgressUpdate: @escaping (Double) -> Void) {
      self.onProgressUpdate = onProgressUpdate
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
      guard let mediaPlayer = mediaPlayer else { return }
      let timeInMs = mediaPlayer.time.intValue
      let seconds = Double(timeInMs) / 1000.0
      onProgressUpdate(seconds)
    }
  }
}

struct VLCPlayerWithControls: View {
  let url: URL
  @State private var isPlaying = false
  @State private var startTime: Double = 0.0
  @State private var mediaDuration: Double = 100.0  // Update as needed
  @State private var isFullScreen = false

  var body: some View {
    VStack {
      VLCPlayerView(
        url: url,
        startTime: $startTime,
        onProgressUpdate: { newTime in
          startTime = newTime
        },
        isPlaying: $isPlaying
      )
      .frame(height: isFullScreen ? UIScreen.main.bounds.height : 250)
      .edgesIgnoringSafeArea(isFullScreen ? .all : [])

      // Progress slider for seeking.
      Slider(value: $startTime, in: 0...mediaDuration)
        .padding()

      // Basic control buttons.
      HStack {
        Button(action: { isPlaying.toggle() }) {
          Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .font(.title)
            .padding()
        }

        Button(action: { startTime = max(startTime - 10, 0) }) {
          Image(systemName: "gobackward.10")
            .font(.title)
            .padding()
        }

        Button(action: { startTime += 10 }) {
          Image(systemName: "goforward.10")
            .font(.title)
            .padding()
        }

        Button(action: { isFullScreen.toggle() }) {
          Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
            .font(.title)
            .padding()
        }
      }
    }
  }
}

#Preview {
    DownloadedMediaListView(serverUrl: "https://yourserverurl.com")
}

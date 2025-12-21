import SwiftUI
import AVKit
import JellyfinAPI

struct DownloadRow: View {
    @ObservedObject var download: DownloadManager.Download
    @State private var showDetails = false

    var body: some View {
        DisclosureGroup(isExpanded: $showDetails) {
            VStack(alignment: .leading, spacing: 6) {
                metricRow(icon: "arrow.down.circle", value: downloadedDescription)
                metricRow(icon: "speedometer", value: speedDescription)
                metricRow(icon: "clock.arrow.circlepath", value: etaDescription)
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(download.baseItem?.name ?? "Downloading...")
                        .font(.headline)
                        .lineLimit(2)
                    Text(progressDescription)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                ProgressView(value: download.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 100)
            }
            .contentShape(Rectangle())
        }
        .padding(.vertical, 4)
    }
    
    private var downloadedDescription: String {
        let downloaded = Self.formattedBytes(download.bytesDownloaded)
        if download.totalBytes > 0 {
            let total = Self.formattedBytes(download.totalBytes)
            return "\(downloaded) / \(total)"
        } else {
            return downloaded
        }
    }
    
    private var speedDescription: String {
        guard download.downloadSpeed > 0 else { return "Calculating..." }
        return Self.formattedSpeed(download.downloadSpeed)
    }
    
    private var etaDescription: String {
        guard let eta = download.estimatedTimeRemaining else {
            return "Calculating..."
        }
        let totalSeconds = max(Int(eta.rounded()), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private var progressDescription: String {
        let percent = Int((download.progress * 100).rounded())
        return "\(percent)%"
    }
    
    private func metricRow(icon: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 18)
            Spacer()
            Text(paddedValue(value))
                .font(.system(.subheadline, design: .monospaced))
                .frame(minWidth: 170, alignment: .trailing)
                .lineLimit(1)
        }
    }
    
    private func paddedValue(_ value: String) -> String {
        let targetLength = 12
        if value.count >= targetLength {
            return value
        }
        return String(repeating: " ", count: targetLength - value.count) + value
    }
    
    static func formattedBytes(_ bytes: Int64) -> String {
        let absolute = Double(abs(bytes))
        let units: [(threshold: Double, label: String)] = [
            (threshold: Double(1 << 30), label: "GB"),
            (threshold: Double(1 << 20), label: "MB"),
            (threshold: Double(1 << 10), label: "KB")
        ]
        for unit in units {
            if absolute >= unit.threshold {
                let value = absolute / unit.threshold
                return String(format: "%.2f %@", value, unit.label)
            }
        }
        return String(format: "%.2f B", absolute)
    }

    private static func formattedSpeed(_ bytesPerSecond: Double) -> String {
        let absolute = abs(bytesPerSecond)
        let units: [(threshold: Double, label: String)] = [
            (threshold: Double(1 << 30), label: "GB"),
            (threshold: Double(1 << 20), label: "MB"),
            (threshold: Double(1 << 10), label: "KB")
        ]
        for unit in units {
            if absolute >= unit.threshold {
                let value = absolute / unit.threshold
                return String(format: "%.1f %@/s", value, unit.label)
            }
        }
        let value = absolute
        return String(format: "%.1f B/s", value)
    }
}

struct DownloadedMediaListView: View {
    let serverUrl: String
    @State private var searchQuery = ""
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var pendingDeleteItems: [DownloadManager.DownloadedItem] = []
    @State private var showDeleteConfirmation = false

    // Filter downloaded items based on the search query.
    var filteredDownloads: [DownloadManager.DownloadedItem] {
        let items = Array(downloadManager.downloadedItems.values)
        if searchQuery.isEmpty {
            return items
        } else {
            return items.filter { ($0.baseItem.name?.localizedCaseInsensitiveContains(searchQuery) ?? false) }
        }
    }
    
    // Filter currently downloading items based on the search query.
    var filteredCurrentDownloads: [DownloadManager.Download] {
        let items = Array(downloadManager.downloads.values)
        if searchQuery.isEmpty {
            return items
        } else {
            return items.filter { ($0.baseItem?.name?.localizedCaseInsensitiveContains(searchQuery) ?? false) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredCurrentDownloads.isEmpty {
                    Section(header: Text("Downloading")) {
                        ForEach(filteredCurrentDownloads, id: \.id) { download in
                            DownloadRow(download: download)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        downloadManager.cancelDownload(for: download.id)
                                    } label: {
                                        Label("Cancel", systemImage: "xmark.circle")
                                    }
                                }
                        }
                    }
                }
                
                Section(header: Text("Downloaded Media"),
                        footer: Text(downloadSummaryText)
                            .font(.footnote)
                            .foregroundColor(.secondary)) {
                    ForEach(filteredDownloads, id: \.id) { downloadedItem in
                        NavigationLink(destination: DownloadedMediaDetailView(downloadedItem: downloadedItem, serverUrl: serverUrl)) {
                            HStack(spacing: 12) {
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
                                        Text("\(year)")
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
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchQuery, prompt: "Search Downloaded Media")
            .navigationTitle("Library")
        }
        .alert("Delete Downloaded Media", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                pendingDeleteItems.forEach { downloadManager.deleteDownloadedItem(for: $0.id) }
                pendingDeleteItems = []
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteItems = []
            }
        } message: {
            if pendingDeleteItems.count == 1 {
                Text("Delete \"\(pendingDeleteItems.first?.baseItem.name ?? "download")\" from your device permanently?")
            } else {
                Text("Delete \(pendingDeleteItems.count) downloads from your device permanently?")
            }
        }
    }
    
    private func getImageUrl(for item: BaseItemDto) -> URL? {
        guard let id = item.id,
              let token = UserDefaults.standard.string(forKey: "accessToken"),
              let url = URL(string: serverUrl) else { return nil }
        return URL(string: "\(url)/Items/\(id)/Images/Primary?api_key=\(token)")
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.compactMap { index -> DownloadManager.DownloadedItem? in
            guard filteredDownloads.indices.contains(index) else { return nil }
            return filteredDownloads[index]
        }
        guard !itemsToDelete.isEmpty else { return }
        pendingDeleteItems = itemsToDelete
        showDeleteConfirmation = true
    }

    private var downloadSummaryText: String {
        let count = downloadManager.downloadedItems.count
        let formattedSize = DownloadRow.formattedBytes(downloadManager.totalDownloadedBytes)
        return "You have \(count) item\(count == 1 ? "" : "s") downloaded totaling \(formattedSize)"
    }
}

struct DownloadedMediaDetailView: View {
    let downloadedItem: DownloadManager.DownloadedItem
    let serverUrl: String
    @State private var playbackProgress: Double = 0.0

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
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }

        let player = AVPlayer(url: url)
        let cmTime = CMTimeMakeWithSeconds(startTime, preferredTimescale: 600)
        player.seek(to: cmTime)

        let controller = AVPlayerViewController()
        controller.player = player
        controller.entersFullScreenWhenPlaybackBegins = true
        controller.exitsFullScreenWhenPlaybackEnds = true

        controller.allowsPictureInPicturePlayback = true
        if #available(iOS 14.2, *) {
            controller.canStartPictureInPictureAutomaticallyFromInline = true
        }

        context.coordinator.player = player
        context.coordinator.addTimeObserver()
        
        player.play()
        
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

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

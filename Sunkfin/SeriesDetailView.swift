import SwiftUI
import JellyfinAPI

struct SeriesDetailView: View {
    let series: BaseItemDto
    let serverUrl: String

    @StateObject private var downloadManager = DownloadManager.shared
    @State private var seasons: [BaseItemDto] = []
    @State private var isLoadingSeasons = false
    @State private var seasonEpisodes: [String: [BaseItemDto]] = [:]
    @State private var expandedSeasonIDs = Set<String>()
    @State private var loadingSeasonIDs = Set<String>()
    @State private var deleteCandidate: DownloadManager.DownloadedItem?
    @State private var showDeleteConfirmation = false

    private var accessToken: String? {
        UserDefaults.standard.string(forKey: "accessToken")
    }

    var body: some View {
        List {
            Section {
                seriesHeader
            }

            Section(header: Text("Seasons")) {
                if isLoadingSeasons {
                    HStack {
                        Spacer()
                        ProgressView("Loading seasons…")
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    }
                } else if seasons.isEmpty {
                    Text("No seasons available for this show.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(seasons.compactMap { $0.id != nil ? $0 : nil }, id: \.id) { season in
                        if let seasonId = season.id {
                            DisclosureGroup(isExpanded: expansionBinding(for: seasonId, season: season)) {
                                if let episodes = seasonEpisodes[seasonId], !episodes.isEmpty {
                                    ForEach(episodes.compactMap { $0.id != nil ? $0 : nil }, id: \.id) { episode in
                                        episodeRow(for: episode)
                                    }
                                } else if loadingSeasonIDs.contains(seasonId) {
                                    HStack {
                                        Spacer()
                                        ProgressView("Loading episodes…")
                                        Spacer()
                                    }
                                } else {
                                    Text("No episodes found.")
                                        .foregroundColor(.secondary)
                                }
                            } label: {
                                seasonHeader(for: season)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

            }
        }
        .navigationTitle(series.name ?? "Series")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .task {
            await fetchSeasons()
        }
        .refreshable {
            await fetchSeasons()
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
            Text("Delete \"\(downloaded.baseItem.name ?? "download")\" permanently?")
        }
    }

    @ViewBuilder
    private var seriesHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            if let imageUrl = series.primaryImageURL(serverUrl: serverUrl, accessToken: accessToken) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 120, height: 180)
                .cornerRadius(12)
                .clipped()
            } else {
                Color.gray.opacity(0.3)
                    .frame(width: 120, height: 180)
                    .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(series.name ?? "Unknown Series")
                    .font(.title2)
                    .bold()
                    .lineLimit(2)

                if let overview = series.overview {
                    Text(overview)
                        .font(.body)
                        .lineLimit(4)
                        .foregroundColor(.secondary)
                }

                if let year = series.productionYear {
                    Text(verbatim: "\(year)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let userData = series.userData {
                    ShowProgressView(hasWatched: userData.isPlayed ?? false, percentage: userData.playedPercentage)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func seasonHeader(for season: BaseItemDto) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(season.name ?? "Season \(season.indexNumber ?? 0)")
                    .font(.headline)
                HStack {
                    if let episodeCount = availableEpisodeCount(for: season) {
                        Text("\(episodeCount) episode\(episodeCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let ticks = season.runTimeTicks {
                        let seconds = ticks / 10_000_000
                        TimeView(seconds: seconds)
                    }
                }
                if let userData = season.userData {
                    ShowProgressView(hasWatched: userData.isPlayed ?? false, percentage: userData.playedPercentage)
                }
            }

            Spacer()

            if let seasonId = season.id {
                Button {
                    Task {
                        await downloadSeason(season)
                    }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(loadingSeasonIDs.contains(seasonId))
            }
        }
    }

    private func availableEpisodeCount(for season: BaseItemDto) -> Int? {
        if let count = season.episodeCount {
            return count
        }
        if let count = season.childCount {
            return count
        }

        if let seasonId = season.id, let episodes = seasonEpisodes[seasonId] {
            return episodes.count
        }

        return nil
    }

    private func episodeRow(for episode: BaseItemDto) -> some View {
        HStack(spacing: 12) {
            if let imageUrl = episode.primaryImageURL(serverUrl: serverUrl, accessToken: accessToken) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 70, height: 90)
                .cornerRadius(8)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.name ?? "Episode")
                    .font(.headline)
                    .lineLimit(2)

                if let userData = episode.userData {
                    ShowProgressView(hasWatched: userData.isPlayed ?? false, percentage: userData.playedPercentage)
                }

                if let ticks = episode.runTimeTicks {
                    let seconds = ticks / 10_000_000
                    TimeView(seconds: seconds)
                }
            }

            Spacer()

            episodeDownloadControl(for: episode)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            switch swipeAction(for: episode) {
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
                    startDownload(for: episode)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .tint(.blue)
                .disabled(!canStartDownload(for: episode))
            }
        }
    }

    private func swipeAction(for item: BaseItemDto) -> LibrarySwipeAction {
        guard let itemId = item.id else {
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

    private func startDownload(for item: BaseItemDto) {
        guard let token = accessToken,
              !token.isEmpty,
              let itemId = item.id else {
            return
        }

        guard downloadManager.downloadedItems[itemId] == nil,
              downloadManager.downloads[itemId] == nil else {
            return
        }

        downloadManager.startDownload(for: item, serverUrl: serverUrl, accessToken: token)
    }

    private func canStartDownload(for item: BaseItemDto) -> Bool {
        guard let token = accessToken,
              !token.isEmpty,
              let itemId = item.id else {
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

    @ViewBuilder
    private func episodeDownloadControl(for episode: BaseItemDto) -> some View {
        if let id = episode.id {
            if let download = downloadManager.downloads[id] {
                ProgressView(value: download.progress)
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(width: 36, height: 36)
            } else if downloadManager.downloadedItems[id] != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .imageScale(.large)
            } else {
                Button {
                    startDownload(for: episode)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(!canStartDownload(for: episode))
            }
        } else {
            EmptyView()
        }
    }

    @MainActor
    private func fetchSeasons() async {
        guard let client = makeClient(), let seriesId = series.id else {
            return
        }

        isLoadingSeasons = true
        seasonEpisodes.removeAll()
        expandedSeasonIDs.removeAll()
        loadingSeasonIDs.removeAll()
        defer { isLoadingSeasons = false }

        do {
            let parameters = Paths.GetSeasonsParameters(enableImages: true, enableUserData: true)
            let response = try await client.send(Paths.getSeasons(seriesID: seriesId, parameters: parameters)).value
            seasons = (response.items ?? [])
                .filter { $0.id != nil }
                .sorted { ($0.indexNumber ?? 0) < ($1.indexNumber ?? 0) }
        } catch {
            print("Failed to load seasons: \(error)")
        }
    }

    @MainActor
    private func fetchEpisodesIfNeeded(for season: BaseItemDto) async {
        guard let seasonId = season.id else { return }
        if seasonEpisodes[seasonId] != nil {
            return
        }

        await fetchEpisodes(for: season)
    }

    @MainActor
    private func fetchEpisodes(for season: BaseItemDto) async {
        guard let client = makeClient(), let seriesId = series.id, let seasonId = season.id else {
            return
        }

        loadingSeasonIDs.insert(seasonId)
        defer { loadingSeasonIDs.remove(seasonId) }

        do {
            let parameters = Paths.GetEpisodesParameters(seasonID: seasonId, enableImages: true, enableUserData: true)
            let response = try await client.send(Paths.getEpisodes(seriesID: seriesId, parameters: parameters)).value
            seasonEpisodes[seasonId] = (response.items ?? [])
                .filter { $0.id != nil }
                .sorted { ($0.indexNumber ?? 0) < ($1.indexNumber ?? 0) }
        } catch {
            print("Failed to load episodes for season \(season.name ?? "??"): \(error)")
        }
    }

    @MainActor
    private func downloadSeason(_ season: BaseItemDto) async {
        guard let seasonId = season.id else { return }
        await fetchEpisodesIfNeeded(for: season)

        guard let episodes = seasonEpisodes[seasonId], !episodes.isEmpty else { return }
        for episode in episodes {
            startDownload(for: episode)
        }
    }

    private func expansionBinding(for seasonId: String, season: BaseItemDto) -> Binding<Bool> {
        Binding(
            get: { expandedSeasonIDs.contains(seasonId) },
            set: { newValue in
                if newValue {
                    expandedSeasonIDs.insert(seasonId)
                    Task {
                        await fetchEpisodesIfNeeded(for: season)
                    }
                } else {
                    expandedSeasonIDs.remove(seasonId)
                }
            }
        )
    }

    private func makeClient() -> JellyfinClient? {
        guard let url = URL(string: serverUrl),
              let token = UserDefaults.standard.string(forKey: "accessToken") else {
            return nil
        }

        let config = JellyfinClient.Configuration(
            url: url,
            client: "Sunkfin",
            deviceName: UIDevice.current.name,
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? "",
            version: "1.0.0"
        )

        return JellyfinClient(configuration: config, accessToken: token)
    }
}

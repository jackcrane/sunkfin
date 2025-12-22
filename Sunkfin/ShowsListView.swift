import SwiftUI
import Get
import JellyfinAPI

struct ShowsListView: View {
    let serverUrl: String
    @State private var libraries: [BaseItemDto] = []
    @State private var items: [BaseItemDto] = []
    @State private var searchQuery = ""
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var selectedLibraryId: String?
    @State private var isLoadingLibraries = false
    @State private var isLoadingItems = false
    @State private var deleteCandidate: DownloadManager.DownloadedItem?
    @State private var showDeleteConfirmation = false
    @State private var isUsingUserViewsFallback = false

    private var accessToken: String? {
        UserDefaults.standard.string(forKey: "accessToken")
    }

    private var storedUserId: String? {
        UserDefaults.standard.string(forKey: "userId")
    }

    private var selectedLibrary: BaseItemDto? {
        if let selectedId = selectedLibraryId,
           let library = libraries.first(where: { $0.id == selectedId }) {
            return library
        }
        return libraries.first
    }

    private var selectedLibraryName: String {
        if let name = selectedLibrary?.name, !name.isEmpty {
            return name
        }
        if isLoadingLibraries {
            return "Loading libraries…"
        }
        return "Library Items"
    }

    private var selectedLibraryTypeDescription: String {
        if let collectionType = selectedLibrary?.collectionType {
            return collectionType.rawValue.capitalized
        }
        if let kind = selectedLibrary?.type {
            return kind.rawValue.capitalized
        }
        return "Library"
    }

    private var filteredItems: [BaseItemDto] {
        if searchQuery.isEmpty {
            return items
        } else {
            return items.filter { $0.name?.localizedCaseInsensitiveContains(searchQuery) == true }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    libraryPicker
                }

                Section {
                    if filteredItems.isEmpty {
                        if isLoadingItems {
                            HStack {
                                Spacer()
                                ProgressView("Loading items…")
                                Spacer()
                            }
                        } else {
                            Text("No items found in this library.")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(filteredItems, id: \.id) { item in
                            NavigationLink(destination: destinationView(for: item)) {
                                rowView(for: item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                switch swipeAction(for: item) {
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
                                        startDownload(for: item)
                                    } label: {
                                        Label("Download", systemImage: "arrow.down.circle")
                                    }
                                    .tint(.blue)
                                    .disabled(!canStartDownload(for: item))
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchQuery, prompt: "Search Library Items")
            .navigationTitle(selectedLibraryName)
            .task {
                await fetchLibraries()
            }
            .refreshable {
                await fetchLibraries()
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

    private var libraryPicker: some View {
        Group {
            if isLoadingLibraries {
                HStack {
                    ProgressView()
                    Text("Loading libraries…")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if libraries.isEmpty {
                Text("No libraries found.")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if isUsingUserViewsFallback {
                        HStack(spacing: 4) {
                            Image(systemName: "person.crop.square.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Showing personal views instead of full libraries.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(libraries, id: \.id) { library in
                                if let id = library.id {
                                    Button {
                                        guard selectedLibraryId != id else { return }
                                        selectedLibraryId = id
                                        Task {
                                            await fetchItems(for: id)
                                        }
                                    } label: {
                                        Text(library.name ?? "Unnamed")
                                            .font(.subheadline)
                                            .foregroundColor(selectedLibraryId == id ? .white : .primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(selectedLibraryId == id ? Color.accentColor : Color(.secondarySystemFill))
                                            )
                                    }
                                    .animation(.easeInOut, value: selectedLibraryId)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }
        }
    }

    private func rowView(for item: BaseItemDto) -> some View {
        HStack(spacing: 12) {
            if let imageUrl = item.primaryImageURL(serverUrl: serverUrl, accessToken: accessToken) {
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
                Text(item.name ?? "Unknown Show")
                    .font(.headline)
                    .lineLimit(2)

                if let year = item.productionYear {
                    Text(verbatim: "\(year)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                    if item.type != .episode, let ticks = item.runTimeTicks {
                        let seconds = ticks / 10_000_000
                        TimeView(seconds: seconds)
                    }

                if let userData = item.userData {
                    ShowProgressView(hasWatched: userData.isPlayed ?? false, percentage: userData.playedPercentage)
                }
            }

            Spacer()
        }
        .frame(height: 120)
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func destinationView(for item: BaseItemDto) -> some View {
        if item.type == .series {
            SeriesDetailView(series: item, serverUrl: serverUrl)
        } else {
            LibraryItemView(item: item, serverUrl: serverUrl)
        }
    }

    @MainActor
    private func fetchLibraries() async {
        guard let client = makeClient() else { return }
        isLoadingLibraries = true
        defer { isLoadingLibraries = false }

        do {
            let response = try await client.send(Paths.getMediaFolders()).value
            let availableLibraries = (response.items ?? [])
                .filter { $0.id != nil }
                .sorted { ($0.name ?? "") < ($1.name ?? "") }
            libraries = availableLibraries

            if let current = selectedLibraryId,
               availableLibraries.contains(where: { $0.id == current }) {
                // Keep the existing selection.
            } else {
                selectedLibraryId = availableLibraries.first?.id
            }

            if let libraryId = selectedLibraryId {
                await fetchItems(for: libraryId)
            } else {
                items = []
            }

            isUsingUserViewsFallback = false
        } catch {
            if let apiError = error as? APIError,
               case .unacceptableStatusCode(403) = apiError {
                await fetchUserViews(using: client)
            } else {
                print("Failed to fetch media libraries: \(error)")
            }
        }
    }

    @MainActor
    private func fetchUserViews(using client: JellyfinClient) async {
        isUsingUserViewsFallback = true
        isLoadingLibraries = true
        defer { isLoadingLibraries = false }

        let userId = await loadCurrentUserIdIfNeeded(using: client)

        do {
            let parameters = Paths.GetUserViewsParameters(userID: userId, isIncludeHidden: false)
            let response = try await client.send(Paths.getUserViews(parameters: parameters)).value
            let availableLibraries = (response.items ?? [])
                .filter { $0.id != nil }
                .sorted { ($0.name ?? "") < ($1.name ?? "") }
            libraries = availableLibraries

            if let current = selectedLibraryId,
               availableLibraries.contains(where: { $0.id == current }) {
                // Keep the existing selection.
            } else {
                selectedLibraryId = availableLibraries.first?.id
            }

            if let libraryId = selectedLibraryId {
                await fetchItems(for: libraryId)
            } else {
                items = []
            }
        } catch {
            print("Failed to fetch user views: \(error)")
        }
    }

    @MainActor
    private func fetchItems(for libraryId: String) async {
        guard let client = makeClient() else { return }
        isLoadingItems = true
        defer { isLoadingItems = false }

        let resolvedUserId = await loadCurrentUserIdIfNeeded(using: client)

        do {
            let response: JellyfinAPI.BaseItemDtoQueryResult

            if let userId = resolvedUserId {
                let parameters = makeUserScopedItemParameters(parentId: libraryId)
                response = try await client.send(Paths.getItemsByUserID(userID: userId, parameters: parameters)).value
            } else {
                let parameters = makeItemsParameters(parentId: libraryId)
                response = try await client.send(Paths.getItems(parameters: parameters)).value
            }

            items = (response.items ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
        } catch {
            print("Failed to fetch library items: \(error)")
        }
    }

    private func makeItemsParameters(parentId: String) -> Paths.GetItemsParameters {
        Paths.GetItemsParameters(
            isRecursive: false,
            parentID: parentId,
            enableUserData: true,
            enableImages: true
        )
    }

    private func makeUserScopedItemParameters(parentId: String) -> Paths.GetItemsByUserIDParameters {
        Paths.GetItemsByUserIDParameters(
            isRecursive: false,
            parentID: parentId,
            enableUserData: true,
            enableImages: true
        )
    }

    @MainActor
    private func loadCurrentUserIdIfNeeded(using client: JellyfinClient) async -> String? {
        if let stored = storedUserId {
            return stored
        }

        do {
            let user = try await client.send(Paths.getCurrentUser).value
            if let id = user.id {
                UserDefaults.standard.setValue(id, forKey: "userId")
                return id
            }
        } catch {
            print("Failed to fetch current user id: \(error)")
        }

        return nil
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
}

#Preview {
    ShowsListView(serverUrl: "https://stream.jackcrane.rocks")
        .onAppear {
            UserDefaults.standard.setValue("8c13cb1bb33549548979709e1734681f", forKey: "accessToken")
        }
}

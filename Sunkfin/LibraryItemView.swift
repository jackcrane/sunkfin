import SwiftUI
import JellyfinAPI

struct LibraryItemView: View {
    let item: BaseItemDto
    let serverUrl: String

    var accessToken: String {
        UserDefaults.standard.string(forKey: "accessToken") ?? ""
    }
    
    @StateObject private var downloadManager = DownloadManager.shared

    @State private var downloadProgress: Double = 0.0
    @State private var isDownloading: Bool = false
    @State private var pendingDeleteItem: DownloadManager.DownloadedItem?
    @State private var showDeleteConfirmation = false

    // Check if the media item has been downloaded.
    var downloadedItem: DownloadManager.DownloadedItem? {
        guard let id = item.id else { return nil }
        return downloadManager.downloadedItems[id]
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 16) {
                if let primaryUrl = item.primaryImageURL(serverUrl: serverUrl, accessToken: accessToken) {
                    AsyncImage(url: primaryUrl) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 150, height: 225)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                }
                
                VStack(alignment: .leading) {
                    Text(item.name ?? "Unknown Item")
                        .font(.title)
                        .bold()
                    
                    if let overview = item.overview {
                        Text(overview)
                            .font(.body)
                            .lineLimit(4)
                    }
                }
                Spacer()
            }
            
            Spacer()
            
            // If the media is downloaded, show "View" and "Delete" buttons.
            if let downloaded = downloadedItem {
                HStack(spacing: 16) {
                    Button(action: {
                        pendingDeleteItem = downloaded
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .frame(width: 50, height: 50)
                            .background(Color.red.opacity(0.6)) // Light red
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    NavigationLink(destination: DownloadedMediaDetailView(downloadedItem: downloaded, serverUrl: serverUrl)) {
                        Text("Watch")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            } else {
                // Otherwise, show the download button (or cancel action if already downloading).
                Button(action: {
                    if isDownloading, let itemId = item.id {
                        downloadManager.cancelDownload(for: itemId)
                    } else {
                        downloadManager.startDownload(for: item, serverUrl: serverUrl, accessToken: accessToken)
                    }
                }) {
                    if let itemId = item.id,
                       let download = downloadManager.downloads[itemId] {
                        HStack(spacing: 0) {
                            DownloadProgressView(download: download)
                                .font(.headline)
                            
                            Text(". Tap to cancel")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isDownloading ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    } else {
                        Text("Download")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isDownloading ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .font(.headline)
                    }
                }
            }
        }
        .padding()
        .navigationTitle(item.name ?? "Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let itemId = item.id, let download = downloadManager.downloads[itemId] {
                isDownloading = true
                downloadProgress = download.progress
            }
        }
        .onReceive(downloadManager.$downloads) { downloads in
            if let itemId = item.id, let download = downloads[itemId] {
                isDownloading = true
                downloadProgress = download.progress
            } else {
                isDownloading = false
            }
        }
        .alert("Delete Download", isPresented: $showDeleteConfirmation, presenting: pendingDeleteItem) { item in
            Button("Delete", role: .destructive) {
                downloadManager.deleteDownloadedItem(for: item.id)
                pendingDeleteItem = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: { item in
            Text("Delete \"\(item.baseItem.name ?? "download")\" permanently?")
        }
    }
}

#Preview {
    LibraryItemView(
        item: BaseItemDto(
            airDays: nil,
            airTime: nil,
            airsAfterSeasonNumber: nil,
            airsBeforeEpisodeNumber: nil,
            airsBeforeSeasonNumber: nil,
            album: nil,
            albumArtist: nil,
            albumArtists: nil,
            albumCount: nil,
            albumID: nil,
            albumPrimaryImageTag: nil,
            altitude: nil,
            aperture: nil,
            artistCount: nil,
            artistItems: nil,
            artists: nil,
            aspectRatio: nil,
            audio: nil,
            backdropImageTags: ["76960762cf39f8448b64792de73cb6a4"],
            cameraMake: nil,
            cameraModel: nil,
            canDelete: nil,
            canDownload: nil,
            channelID: nil,
            channelName: nil,
            channelNumber: nil,
            channelPrimaryImageTag: nil,
            channelType: nil,
            chapters: nil,
            childCount: nil,
            collectionType: nil,
            communityRating: 7.028,
            completionPercentage: nil,
            container: "mov,mp4,m4a,3gp,3g2,mj2",
            criticRating: 97.0,
            cumulativeRunTimeTicks: nil,
            customRating: nil,
            dateCreated: nil,
            dateLastMediaAdded: nil,
            displayOrder: nil,
            displayPreferencesID: nil,
            enableMediaSourceDisplay: nil,
            endDate: nil,
            episodeCount: nil,
            episodeTitle: nil,
            etag: nil,
            exposureTime: nil,
            externalURLs: nil,
            extraType: nil,
            focalLength: nil,
            forcedSortName: nil,
            genreItems: nil,
            genres: nil,
            hasLyrics: nil,
            hasSubtitles: nil,
            height: nil,
            id: "02f9fd6d211a75a7ee3211152dfb9319",
            imageBlurHashes: JellyfinAPI.BaseItemDto.ImageBlurHashes(
                art: nil,
                backdrop: [
                    "76960762cf39f8448b64792de73cb6a4": "WHBLYmoY5QWS-qs*?1NqNGngtAfzb5WR$$axNgR$s[nfoJXRs=nN"
                ],
                banner: nil,
                box: nil,
                boxRear: nil,
                chapter: nil,
                disc: nil,
                logo: [
                    "a163beadb45d057c4fc34462e6075fe8": "PIONB[IU?b~qRj9F9F-;-;ofayD%M{RjxuRjM{xuRjIUIUxuxuRj"
                ],
                menu: nil,
                primary: [
                    "614d8ecadfe7f2dba904a319ed858cff": "dsQk+qr=%0~V+WxuV?R4adaekXj]%Me.WCbdxYtRRjRQ"
                ],
                profile: nil,
                screenshot: nil,
                thumb: [
                    "3551f6f77ff68f1660afcf4389e2173f": "W$JGSj}:xW$}$|-QjZ$$s.WCxYa{$~ocWVa#R,f8-lxWNIR+s-s."
                ]
            ),
            imageOrientation: nil,
            imageTags: [
                "Logo": "a163beadb45d057c4fc34462e6075fe8",
                "Primary": "614d8ecadfe7f2dba904a319ed858cff",
                "Thumb": "3551f6f77ff68f1660afcf4389e2173f"
            ],
            indexNumber: nil,
            indexNumberEnd: nil,
            isFolder: false,
            isHD: nil,
            isKids: nil,
            isLive: nil,
            isMovie: nil,
            isNews: nil,
            isPlaceHolder: nil,
            isPremiere: nil,
            isRepeat: nil,
            isSeries: nil,
            isSports: nil,
            isoSpeedRating: nil,
            isoType: nil,
            latitude: nil,
            localTrailerCount: nil,
            locationType: JellyfinAPI.LocationType.fileSystem,
            lockData: nil,
            lockedFields: nil,
            longitude: nil,
            mediaSourceCount: nil,
            mediaSources: nil,
            mediaStreams: nil,
            mediaType: JellyfinAPI.MediaType.video,
            movieCount: nil,
            musicVideoCount: nil,
            name: "Hit Man",
            normalizationGain: nil,
            number: nil,
            officialRating: "R",
            originalTitle: nil,
            overview: "A brief overview of the movie goes here.",
            parentArtImageTag: nil,
            parentArtItemID: nil,
            parentBackdropImageTags: nil,
            parentBackdropItemID: nil,
            parentID: nil,
            parentIndexNumber: nil,
            parentLogoImageTag: nil,
            parentLogoItemID: nil,
            parentPrimaryImageTag: nil,
            parentThumbImageTag: nil,
            parentThumbItemID: nil,
            partCount: nil,
            path: nil,
            people: nil,
            playAccess: nil,
            playlistItemID: nil,
            preferredMetadataCountryCode: nil,
            preferredMetadataLanguage: nil,
            premiereDate: Date(timeIntervalSince1970: 1715817600),
            primaryImageAspectRatio: nil,
            productionLocations: nil,
            productionYear: 2024,
            programCount: nil,
            programID: nil,
            providerIDs: nil,
            recursiveItemCount: nil,
            remoteTrailers: nil,
            runTimeTicks: 69394880000,
            screenshotImageTags: nil,
            seasonID: nil,
            seasonName: nil,
            seriesCount: nil,
            seriesID: nil,
            seriesName: nil,
            seriesPrimaryImageTag: nil,
            seriesStudio: nil,
            seriesThumbImageTag: nil,
            seriesTimerID: nil,
            serverID: "fcace5155226477cb24bc1fc19b5b0b9",
            shutterSpeed: nil,
            software: nil,
            songCount: nil,
            sortName: nil,
            sourceType: nil,
            specialFeatureCount: nil,
            startDate: nil,
            status: nil,
            studios: nil,
            taglines: nil,
            tags: nil,
            timerID: nil,
            trailerCount: nil,
            trickplay: nil,
            type: JellyfinAPI.BaseItemKind.movie,
            userData: JellyfinAPI.UserItemDataDto(
                isFavorite: false,
                itemID: "00000000000000000000000000000000",
                key: "974635",
                lastPlayedDate: Date(timeIntervalSince1970: 1729749752),
                isLikes: nil,
                playCount: 3,
                playbackPositionTicks: 0,
                isPlayed: true,
                playedPercentage: nil
            ),
            video3DFormat: nil,
            videoType: JellyfinAPI.VideoType.videoFile,
            width: nil
        ),
        serverUrl: "https://stream.jackcrane.rocks"
    )
    .onAppear {
        UserDefaults.standard.setValue("8c13cb1bb33549548979709e1734681f", forKey: "accessToken")
    }
}

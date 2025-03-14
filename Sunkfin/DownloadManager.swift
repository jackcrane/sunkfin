import Foundation
import SwiftUI
import JellyfinAPI

final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()
    
    // A download record for an item.
    final class Download: Identifiable, ObservableObject {
        let id: String
        var baseItem: BaseItemDto? // Store metadata for later use.
        @Published var progress: Double = 0.0
        @Published var isDownloading: Bool = false
        var task: URLSessionDownloadTask?
        var progressObservation: NSKeyValueObservation?
        
        init(id: String, baseItem: BaseItemDto? = nil) {
            self.id = id
            self.baseItem = baseItem
        }
    }
    
    // Struct to track downloaded items along with their metadata.
    struct DownloadedItem: Identifiable, Codable {
        let id: String
        let baseItem: BaseItemDto
        let fileURL: URL
    }
    
    @Published var downloads: [String: Download] = [:]
    @Published var downloadedItems: [String: DownloadedItem] = [:]
    
    // Create a background URLSession with a unique identifier.
    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.myapp.backgroundSession")
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    override init() {
        super.init()
        loadDownloadedItems()
    }
    
    /// Scans the documents directory and loads previously downloaded items.
    private func loadDownloadedItems() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            // Look for JSON files that store metadata.
            for fileURL in fileURLs where fileURL.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    let baseItem = try decoder.decode(BaseItemDto.self, from: data)
                    guard let itemId = baseItem.id else { continue }
                    let mp4FileURL = documentsPath.appendingPathComponent("\(itemId).mp4")
                    // Ensure the media file exists.
                    if FileManager.default.fileExists(atPath: mp4FileURL.path) {
                        let downloadedItem = DownloadedItem(id: itemId, baseItem: baseItem, fileURL: mp4FileURL)
                        downloadedItems[itemId] = downloadedItem
                        print("Loaded downloaded item: \(itemId)")
                    }
                } catch {
                    print("Error loading downloaded item from \(fileURL.path): \(error)")
                }
            }
        } catch {
            print("Error listing documents directory: \(error)")
        }
    }
    
    /// Starts a background download for a given item.
    func startDownload(for item: BaseItemDto, serverUrl: String, accessToken: String) {
        guard let itemId = item.id,
              let url = URL(string: "\(serverUrl)/Items/\(itemId)/Download?api_key=\(accessToken)") else {
            print("Invalid URL or item id.")
            return
        }
        
        let download = Download(id: itemId, baseItem: item)
        download.isDownloading = true
        downloads[itemId] = download
        
        let task = backgroundSession.downloadTask(with: url)
        // Use taskDescription to store the item id for retrieval in delegate callbacks.
        task.taskDescription = itemId
        download.task = task
        
        // Observe the download progress.
        download.progressObservation = task.progress.observe(\.fractionCompleted, options: [.new]) { progress, change in
            if let newValue = change.newValue {
                DispatchQueue.main.async {
                    download.progress = newValue
                }
            }
            print("Download progress for \(itemId): \(progress.fractionCompleted)")
        }
        
        task.resume()
    }
    
    /// Cancels the download for a given item id.
    func cancelDownload(for itemId: String) {
        if let download = downloads[itemId] {
            download.task?.cancel()
            download.isDownloading = false
            downloads.removeValue(forKey: itemId)
            print("Download cancelled for \(itemId)")
        }
    }
    
    /// Deletes a downloaded item and removes all associated files.
    func deleteDownloadedItem(for itemId: String) {
        guard let downloadedItem = downloadedItems[itemId] else {
            print("No downloaded item found with id: \(itemId)")
            return
        }
        
        let fileManager = FileManager.default
        
        // Delete the media file.
        do {
            if fileManager.fileExists(atPath: downloadedItem.fileURL.path) {
                try fileManager.removeItem(at: downloadedItem.fileURL)
                print("Deleted file at: \(downloadedItem.fileURL.path)")
            }
        } catch {
            print("Error deleting file at \(downloadedItem.fileURL.path): \(error)")
        }
        
        // Delete the metadata JSON file.
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let jsonURL = documentsPath.appendingPathComponent("\(itemId).json")
        do {
            if fileManager.fileExists(atPath: jsonURL.path) {
                try fileManager.removeItem(at: jsonURL)
                print("Deleted metadata file at: \(jsonURL.path)")
            }
        } catch {
            print("Error deleting metadata file at \(jsonURL.path): \(error)")
        }
        
        // Remove the item from our tracking dictionary.
        downloadedItems.removeValue(forKey: itemId)
        print("Removed downloaded item with id: \(itemId) from memory.")
    }
    
    // MARK: - URLSessionDownloadDelegate Methods
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Retrieve the item id from the task description.
        guard let itemId = downloadTask.taskDescription else {
            print("Task description missing.")
            return
        }
        
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(itemId).mp4")
        
        // Ensure the destination directory exists.
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating directory: \(error)")
            }
        }
        
        // Overwrite any existing file at destination.
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                print("Error removing existing file: \(error)")
            }
        }
        
        // Immediately move the downloaded file to the destination.
        do {
            try fileManager.moveItem(at: location, to: fileURL)
            print("File saved to: \(fileURL.path)")
        } catch {
            print("Error moving file: \(error)")
            return // Exit if the move fails.
        }
        
        // Save the metadata JSON file.
        if let download = downloads[itemId], let baseItem = download.baseItem {
            let jsonURL = documentsPath.appendingPathComponent("\(itemId).json")
            if fileManager.fileExists(atPath: jsonURL.path) {
                do {
                    try fileManager.removeItem(at: jsonURL)
                } catch {
                    print("Error removing existing metadata file: \(error)")
                }
            }
            do {
                let data = try JSONEncoder().encode(baseItem)
                try data.write(to: jsonURL)
                print("Metadata saved to: \(jsonURL.path)")
            } catch {
                print("Error saving metadata: \(error)")
            }
        }
        
        // Update tracking dictionaries on the main thread.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.downloads[itemId]?.isDownloading = false
            if let download = self.downloads[itemId], let baseItem = download.baseItem {
                let downloadedItem = DownloadedItem(id: itemId, baseItem: baseItem, fileURL: fileURL)
                self.downloadedItems[itemId] = downloadedItem
            }
            self.downloads.removeValue(forKey: itemId)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let itemId = task.taskDescription else { return }
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                print("Download error for \(itemId): \(error)")
            }
            self?.downloads.removeValue(forKey: itemId)
        }
    }
}

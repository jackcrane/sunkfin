import Foundation
import SwiftUI
import JellyfinAPI

final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    // A download record for an item.
    final class Download: Identifiable, ObservableObject {
        let id: String
        @Published var progress: Double = 0.0
        @Published var isDownloading: Bool = false
        var task: URLSessionDownloadTask?
        var progressObservation: NSKeyValueObservation?
        
        init(id: String) {
            self.id = id
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
    
    init() {
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
    
    /// Starts a download for a given item.
    func startDownload(for item: BaseItemDto, serverUrl: String, accessToken: String) {
        guard let itemId = item.id,
              let url = URL(string: "\(serverUrl)/Items/\(itemId)/Download?api_key=\(accessToken)") else {
            print("Invalid URL or item id.")
            return
        }
        
        let download = Download(id: itemId)
        download.isDownloading = true
        downloads[itemId] = download
        
        let task = URLSession.shared.downloadTask(with: url) { [weak self, weak download] tempURL, response, error in
            DispatchQueue.main.async {
                guard let download = download else { return }
                download.isDownloading = false
                if let error = error {
                    print("Download error: \(error)")
                    self?.downloads.removeValue(forKey: itemId)
                    return
                }
                guard let tempURL = tempURL else {
                    print("No temporary file URL found")
                    self?.downloads.removeValue(forKey: itemId)
                    return
                }
                
                do {
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    // Move the downloaded file to the documents directory.
                    let fileURL = documentsPath.appendingPathComponent("\(itemId).mp4")
                    try FileManager.default.moveItem(at: tempURL, to: fileURL)
                    print("File saved to: \(fileURL.path)")
                    
                    // Save the BaseItemDto metadata offline as JSON.
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(item)
                    let jsonURL = documentsPath.appendingPathComponent("\(itemId).json")
                    try data.write(to: jsonURL)
                    print("Metadata saved to: \(jsonURL.path)")
                    
                    // Track the downloaded file and its associated metadata.
                    let downloadedItem = DownloadedItem(id: itemId, baseItem: item, fileURL: fileURL)
                    self?.downloadedItems[itemId] = downloadedItem
                    
                } catch {
                    print("Error saving file or metadata: \(error)")
                }
                self?.downloads.removeValue(forKey: itemId)
            }
        }
        
        download.task = task
        // Observe the progress so it updates our published value.
        download.progressObservation = task.progress.observe(\.fractionCompleted, options: [.new]) { (progress: Progress, change: NSKeyValueObservedChange<Double>) in
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
}

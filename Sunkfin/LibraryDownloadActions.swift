import Foundation

enum LibrarySwipeAction {
    case delete(DownloadManager.DownloadedItem)
    case cancel(String)
    case download
}

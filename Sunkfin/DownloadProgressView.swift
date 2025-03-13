import SwiftUI

struct DownloadProgressView: View {
  @ObservedObject var download: DownloadManager.Download

  var body: some View {
    VStack {
      Text("Downloading \(Int(download.progress * 100))%")
//        .font(./*subheadline*/)
    }
  }
}

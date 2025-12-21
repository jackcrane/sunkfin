import SwiftUI

struct TimeView: View {
    let seconds: Int

    private var formattedTime: String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
            Text(formattedTime)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }
}

struct ShowProgressView: View {
    let hasWatched: Bool
    let percentage: Double?

    var body: some View {
        HStack(spacing: 4) {
            if hasWatched, percentage == nil {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
                Text("Watched")
                    .foregroundColor(.blue)
                    .font(.subheadline)
            } else if let percentage = percentage {
                ProgressView(value: percentage, total: 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 100)
            }
        }
    }
}

import SwiftUI
import UIKit

struct LogsView: View {
    @StateObject private var logManager = LogManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if logManager.contents.isEmpty {
                    Text("No logs yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    Text(logManager.contents)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        logManager.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(logManager.contents.isEmpty)
                }
            }
        }
        .onAppear {
            logManager.reload()
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityView(activityItems: [logManager.logFileURL])
        }

    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

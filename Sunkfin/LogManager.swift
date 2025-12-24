import Combine
import Foundation

final class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published private(set) var contents: String = ""

    private let fileURL: URL
    private let workQueue = DispatchQueue(label: "Sunkfin.LogManager", qos: .utility)

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter
    }()

    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsDirectory.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
        fileURL = logsDirectory.appendingPathComponent("sunkfin.log")
        reload()
    }

    func log(_ message: String) {
        let entry = "\(Self.timestampFormatter.string(from: Date())) \(message)\n"
        workQueue.async { [fileURL] in
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
            }

            guard let handle = try? FileHandle(forWritingTo: fileURL) else {
                return
            }

            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
            self.loadContents(from: fileURL)
        }
    }

    func reload() {
        workQueue.async { [fileURL] in
            self.loadContents(from: fileURL)
        }
    }

    private func loadContents(from url: URL) {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            DispatchQueue.main.async {
                self.contents = ""
            }
            return
        }

        DispatchQueue.main.async {
            self.contents = text
        }
    }

    var logFileURL: URL {
        fileURL
    }
}

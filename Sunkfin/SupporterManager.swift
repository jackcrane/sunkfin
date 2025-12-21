import Foundation

final class SupporterManager: ObservableObject {
    static let shared = SupporterManager()

    @Published private(set) var isSupporter: Bool = false
    @Published private(set) var expiryDate: Date?

    private let supporterFlagKey = "supporterEnabled"
    private let expiryKey = "supporterExpiryDate"
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd yyyy"
        return formatter
    }()

    private init() {
        load()
        enforceExpiryIfNeeded()
    }

    private func load() {
        let defaults = UserDefaults.standard
        isSupporter = defaults.bool(forKey: supporterFlagKey)
        expiryDate = defaults.object(forKey: expiryKey) as? Date
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(isSupporter, forKey: supporterFlagKey)
        defaults.set(expiryDate, forKey: expiryKey)
    }

    private func enforceExpiryIfNeeded() {
        guard let expiry = expiryDate else { return }
        if expiry <= Date() {
            isSupporter = false
            expiryDate = nil
            persist()
        }
    }

    var isSupporterActive: Bool {
        enforceExpiryIfNeeded()
        return isSupporter
    }

    var expiryDisplayText: String? {
        guard let expiry = expiryDate else { return nil }
        return formatter.string(from: expiry)
    }

    func setSupporter(expiry: Date?) {
        if let expiry = expiry, expiry > Date() {
            isSupporter = true
            expiryDate = expiry
        } else {
            isSupporter = false
            expiryDate = nil
        }
        persist()
    }

    func clearSupporter() {
        setSupporter(expiry: nil)
    }
}

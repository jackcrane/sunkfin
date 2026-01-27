import Foundation
import JellyfinAPI
import PostHog

/// Centralized wrapper around PostHog so analytics calls stay consistent and testable.
enum Analytics {
    static func resumeIdentityFromStoredCredentials() {
        let userId = UserDefaults.standard.string(forKey: "userId")
        let username = UserDefaults.standard.string(forKey: "username")
        let serverUrl = UserDefaults.standard.string(forKey: "serverUrl")
        identifyUser(userId: userId, username: username, serverUrl: serverUrl)
    }

    static func identifyUser(userId: String?, username: String?, serverUrl: String?) {
        guard let distinctId = userId ?? username, !distinctId.isEmpty else { return }

        var userProps: [String: Any] = [:]
        if let userId, !userId.isEmpty { userProps["user_id"] = userId }
        if let username, !username.isEmpty { userProps["username"] = username }
        if let serverUrl, !serverUrl.isEmpty { userProps["server_url"] = serverUrl }

        PostHogSDK.shared.identify(distinctId, userProperties: userProps)
        if let serverUrl, !serverUrl.isEmpty {
            PostHogSDK.shared.register(["server_url": serverUrl])
        }
    }

    static func trackLogin(userId: String?, username: String?, serverUrl: String?) {
        identifyUser(userId: userId, username: username, serverUrl: serverUrl)

        PostHogSDK.shared.capture(
            "user_login",
            properties: [
                "user_id": userId as Any,
                "username": username as Any,
                "server_url": serverUrl as Any
            ].compactMapValues { $0 }
        )
    }

    static func trackLogout(userId: String?, username: String?) {
        PostHogSDK.shared.capture(
            "user_logout",
            properties: [
                "user_id": userId as Any,
                "username": username as Any
            ].compactMapValues { $0 }
        )
        PostHogSDK.shared.reset()
    }

    static func trackDonationModalShown(totalDownloadedBytes: Int64) {
        PostHogSDK.shared.capture(
            "donation_modal_shown",
            properties: [
                "total_downloaded_bytes": totalDownloadedBytes,
                "total_downloaded_human": formattedBytes(totalDownloadedBytes),
                "trigger": "auto_on_launch"
            ]
        )
    }

    static func trackDownloadStarted(for item: BaseItemDto?, expectedBytes: Int64, serverUrl: String?) {
        let isEpisode = item?.type == .episode
        let properties: [String: Any] = [
            "item_id": item?.id as Any,
            "title": item?.name as Any,
            "is_episode": isEpisode,
            "content_type": item?.type?.rawValue as Any,
            "series_name": item?.seriesName as Any,
            "season_name": item?.seasonName as Any,
            "episode_number": item?.indexNumber as Any,
            "server_url": serverUrl as Any,
            "expected_bytes": expectedBytes,
            "expected_size_human": formattedBytes(expectedBytes)
        ].compactMapValues { $0 }

        PostHogSDK.shared.capture("download_started", properties: properties)
    }

    private static func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

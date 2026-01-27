import Foundation
import PostHog
import UIKit

@objc(AppDelegate)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let config = PostHogConfig(
            apiKey: "phc_4XaseZlQYkuoZrINORyAGrrJ6N3OihTLgj6FySPjUKD",
            host: "https://us.i.posthog.com"
        )

        // Faster feedback while validating events locally.
        config.flushAt = 1
        config.flushIntervalSeconds = 10
        config.debug = true

        // Enable mobile session replay without masking inputs or imagery.
        config.sessionReplay = true
        config.sessionReplayConfig.maskAllImages = false
        config.sessionReplayConfig.maskAllTextInputs = false
        config.sessionReplayConfig.screenshotMode = true

        // Capture lifecycle/screen events to enrich session context.
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true

        PostHogSDK.shared.setup(config)
        return true
    }
}

import Foundation
import JellyfinAPI

extension BaseItemDto {
    /// Builds the primary image URL that mirrors how the API fetches artwork.
    func primaryImageURL(serverUrl: String, accessToken: String?) -> URL? {
        guard let id = id, let sanitizedServer = URL(string: serverUrl) else {
            return nil
        }

        let apiKey = accessToken ?? ""
        return URL(string: "\(sanitizedServer)/Items/\(id)/Images/Primary?api_key=\(apiKey)")
    }
}

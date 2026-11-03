import Foundation

/// Resolves the AI proxy. Remote Config may override the URL; anything that is not https stays on the baked Cloud Run default.
enum AIProxyEndpoint {
    static let fallbackURLString = "https://vertexproxy-ryy2hh2k3a-uc.a.run.app"
    static let remoteConfigKey = "ai_proxy_url"

    static var fallbackURL: URL {
        URL(string: fallbackURLString)!
    }

    static func resolve(configured: String?) -> URL {
        let trimmed = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let url = URL(string: trimmed),
              url.scheme == "https",
              url.host != nil else {
            return fallbackURL
        }
        return url
    }
}

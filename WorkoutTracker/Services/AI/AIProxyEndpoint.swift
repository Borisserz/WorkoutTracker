import Foundation

/// Resolves the AI proxy. Remote Config may override the URL; anything that is not https stays on the baked Cloud Run default.
nonisolated enum AIProxyEndpoint {
    static let fallbackURLString = "https://vertexproxy-ryy2hh2k3a-uc.a.run.app"
    static let remoteConfigKey = "ai_proxy_url"
    private static let allowedDefaultHost = "vertexproxy-ryy2hh2k3a-uc.a.run.app"
    private static let cloudRunProjectHash = "-ryy2hh2k3a-"
    private static let cloudFunctionsProjectSuffix = "-serzhanovich-ecosystem-ce700.cloudfunctions.net"

    static var fallbackURL: URL {
        URL(string: fallbackURLString)!
    }

    static func resolve(configured: String?) -> URL {
        let trimmed = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              let host = url.host?.lowercased(),
              isTrustedHost(host) else {
            return fallbackURL
        }
        return url
    }

    private static func isTrustedHost(_ host: String) -> Bool {
        if host == allowedDefaultHost { return true }
        if host.contains(cloudRunProjectHash), host.hasSuffix(".a.run.app") { return true }
        if host.hasSuffix(cloudFunctionsProjectSuffix) { return true }
        return false
    }
}

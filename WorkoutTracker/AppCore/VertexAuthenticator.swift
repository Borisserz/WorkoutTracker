

import Foundation
import SwiftJWT

struct VertexCredentials: Codable, Sendable {
    let project_id: String
    let private_key: String
    let client_email: String

    static func load() async throws -> VertexCredentials {
        let jsonString = await RemoteConfigManager.shared.getString(forKey: "vertex_credentials_json")
        
        guard let data = jsonString.data(using: .utf8), !jsonString.isEmpty else {
            throw URLError(.cannotDecodeRawData)
        }
        
        return try JSONDecoder().decode(VertexCredentials.self, from: data)
    }
}

struct GoogleClaims: Claims {
    let iss: String
    let scope: String
    let aud: String
    let exp: Int 
    let iat: Int 
}

struct GoogleTokenResponse: Codable {
    let access_token: String
    let expires_in: Int
}

actor VertexAuthenticator {
    static let shared = VertexAuthenticator()

    private var cachedToken: String?
    private var tokenExpirationDate: Date?

    private init() {}

    func getValidAccessToken() async throws -> String {

        if let token = cachedToken, let expDate = tokenExpirationDate, expDate > Date().addingTimeInterval(300) {
            return token
        }

        return try await fetchNewToken()
    }

    func getProjectId() async throws -> String {
           return try await VertexCredentials.load().project_id
       }

       private func fetchNewToken() async throws -> String {
           let credentials = try await VertexCredentials.load()
           
           let now = Date().timeIntervalSince1970
            let claims = GoogleClaims(
                iss: credentials.client_email,
                scope: "https://www.googleapis.com/auth/cloud-platform",
                aud: "https://oauth2.googleapis.com/token",
                exp: Int(now + 3600), 
                iat: Int(now)         
            )

        let privateKeyData = credentials.private_key.data(using: .utf8)!
        let jwtSigner = JWTSigner.rs256(privateKey: privateKeyData)
        var jwt = JWT(claims: claims)
        let signedJWT = try jwt.sign(using: jwtSigner)

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(signedJWT)"
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            throw NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch token: \(errorMsg)"])
        }

        let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)

        self.cachedToken = tokenResponse.access_token
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))

        return tokenResponse.access_token
    }
}

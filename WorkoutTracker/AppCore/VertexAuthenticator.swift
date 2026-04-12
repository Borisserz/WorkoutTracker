//
//  VertexAuthenticator.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 12.04.26.
//

import Foundation
import SwiftJWT

// 1. Модель для чтения твоего JSON файла
struct VertexCredentials: Codable, Sendable {
    let project_id: String
    let private_key: String
    let client_email: String
    
    static func load() throws -> VertexCredentials {
        guard let url = Bundle.main.url(forResource: "vertex_credentials", withExtension: "json") else {
            throw URLError(.fileDoesNotExist)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VertexCredentials.self, from: data)
    }
}

// 2. Требования Google для JWT
struct GoogleClaims: Claims {
    let iss: String
    let scope: String
    let aud: String
    let exp: Int // ✅ ИСПРАВЛЕНИЕ: Должен быть Int
    let iat: Int // ✅ ИСПРАВЛЕНИЕ: Должен быть Int
}

// 3. Ответ от сервера Google с токеном
struct GoogleTokenResponse: Codable {
    let access_token: String
    let expires_in: Int
}

// 4. Сам Аутентификатор
actor VertexAuthenticator {
    static let shared = VertexAuthenticator()
    
    private var cachedToken: String?
    private var tokenExpirationDate: Date?
    
    private init() {}
    
    func getValidAccessToken() async throws -> String {
        // Если токен есть и он еще жив (с запасом в 5 минут), отдаем его
        if let token = cachedToken, let expDate = tokenExpirationDate, expDate > Date().addingTimeInterval(300) {
            return token
        }
        
        // Иначе генерируем новый
        return try await fetchNewToken()
    }
    
    func getProjectId() throws -> String {
        return try VertexCredentials.load().project_id
    }
    
    private func fetchNewToken() async throws -> String {
            let credentials = try VertexCredentials.load()
            
            let now = Date().timeIntervalSince1970
            let claims = GoogleClaims(
                iss: credentials.client_email,
                scope: "https://www.googleapis.com/auth/cloud-platform",
                aud: "https://oauth2.googleapis.com/token",
                exp: Int(now + 3600), // ✅ ИСПРАВЛЕНО
                iat: Int(now)         // ✅ ИСПРАВЛЕНО
            )
        
        // 2. Подписываем приватным ключом (RS256)
        let privateKeyData = credentials.private_key.data(using: .utf8)!
        let jwtSigner = JWTSigner.rs256(privateKey: privateKeyData)
        var jwt = JWT(claims: claims)
        let signedJWT = try jwt.sign(using: jwtSigner)
        
        // 3. Отправляем запрос в Google для обмена JWT на Access Token
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
        
        // 4. Кэшируем токен
        self.cachedToken = tokenResponse.access_token
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        
        return tokenResponse.access_token
    }
}

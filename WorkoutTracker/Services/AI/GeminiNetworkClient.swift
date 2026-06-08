import Foundation
import FirebaseAppCheck
import FirebaseAuth

// MARK: - Gemini Schema

nonisolated public enum GeminiSchemaType: String, Codable, Sendable {
    case object = "OBJECT"
    case array = "ARRAY"
    case string = "STRING"
    case integer = "INTEGER"
    case number = "NUMBER"
    case boolean = "BOOLEAN"
}

nonisolated public final class GeminiSchema: Codable, Sendable {
    let type: GeminiSchemaType
    let properties: [String: GeminiSchema]?
    let items: GeminiSchema?
    let required: [String]?
    let description: String?

    public init(type: GeminiSchemaType,
                properties: [String: GeminiSchema]? = nil,
                items: GeminiSchema? = nil,
                required: [String]? = nil,
                description: String? = nil) {
        self.type = type
        self.properties = properties
        self.items = items
        self.required = required
        self.description = description
    }
}

// MARK: - Gemini Request / Response

nonisolated struct GeminiRequest: Codable, Sendable {
    struct Part: Codable, Sendable { let text: String }
    struct Content: Codable, Sendable { let role: String; let parts: [Part] }
    struct SystemInstruction: Codable, Sendable { let parts: [Part] }
    struct GenerationConfig: Codable, Sendable {
        let temperature: Double
        let responseMimeType: String?
        let responseSchema: GeminiSchema?
    }

    let systemInstruction: SystemInstruction?
    let contents: [Content]
    let generationConfig: GenerationConfig
}

nonisolated private struct GeminiResponse: Codable, Sendable {
    struct Candidate: Codable, Sendable {
        struct Content: Codable, Sendable {
            struct Part: Codable, Sendable { let text: String }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

nonisolated private struct GoogleCloudErrorResponse: Codable, Sendable {
    struct ErrorDetail: Codable, Sendable {
        let code: Int?
        let message: String?
        let status: String?
    }
    let error: ErrorDetail?
}

// MARK: - Network client

actor GeminiNetworkClient {
    private let urlSession: URLSession
    private let functionURL = "https://vertexproxy-ryy2hh2k3a-uc.a.run.app"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
    }

    private func makeRequest(stream: Bool, body: GeminiRequest) async throws -> URLRequest {
        guard UserDefaults.standard.bool(
            forKey: Constants.UserDefaultsKeys.hasConsentedToAI.rawValue
        ) else {
            throw AILogicError.aiConsentRequired
        }

       
        guard var comps = URLComponents(string: functionURL) else { throw AILogicError.invalidURL }
        if stream { comps.queryItems = [URLQueryItem(name: "stream", value: "true")] }
        guard let url = comps.url else { throw AILogicError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // App Check (verifies the app/install).
        let token = try await AppCheck.appCheck().token(forcingRefresh: false)
        request.setValue(token.token, forHTTPHeaderField: "X-Firebase-AppCheck")

        // Firebase ID token (identifies the user → server enforces per-user rate limit).
        let firebaseUser = try await AnonymousAuthBootstrap.shared.ensureSignedIn()
        let idToken = try await firebaseUser.getIDToken()
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func executeWithRetry<T>(maxRetries: Int = 3, operation: () async throws -> T) async throws -> T {
        var attempts = 0
        while true {
            do {
                return try await operation()
            } catch let error as AILogicError {
                if case .rateLimited = error {
                    attempts += 1
                    if attempts > maxRetries { throw error }
                    let delay = pow(2.0, Double(attempts)) // 2s, 4s, 8s
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
            } catch {
                throw error
            }
        }
    }

    func generateText(from requestBody: GeminiRequest) async throws -> String {
        return try await executeWithRetry {
            let request = try await makeRequest(stream: false, body: requestBody)
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AILogicError.invalidResponse }

            if http.statusCode == 429 {
                throw AILogicError.rateLimited(retryAfter: nil)
            }

            guard (200...299).contains(http.statusCode) else {
                if http.statusCode == 400 {
                    if let errorResp = try? JSONDecoder().decode(GoogleCloudErrorResponse.self, from: data),
                       let msg = errorResp.error?.message {
                        throw AILogicError.badRequest(reason: msg)
                    }
                }
                let msg = String(data: data, encoding: .utf8) ?? "Unknown Error"
                throw AILogicError.apiError(statusCode: http.statusCode, message: msg)
            }
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let text = decoded.candidates.first?.content.parts.first?.text else { throw AILogicError.noDataReturned }
            return text
        }
    }

    func streamText(from requestBody: GeminiRequest) async throws -> AsyncThrowingStream<String, Error> {
        return try await executeWithRetry {
            let request = try await makeRequest(stream: true, body: requestBody)
            let (bytes, response) = try await urlSession.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw AILogicError.invalidResponse }

            if http.statusCode == 429 {
                throw AILogicError.rateLimited(retryAfter: nil)
            }

            guard (200...299).contains(http.statusCode) else {
                var errorBody = ""
                for try await line in bytes.lines { errorBody += line }
                if http.statusCode == 400 {
                    if let data = errorBody.data(using: .utf8),
                       let errorResp = try? JSONDecoder().decode(GoogleCloudErrorResponse.self, from: data),
                       let msg = errorResp.error?.message {
                        throw AILogicError.badRequest(reason: msg)
                    }
                }
                throw AILogicError.apiError(statusCode: http.statusCode, message: errorBody)
            }
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        for try await line in bytes.lines {
                            guard line.hasPrefix("data: ") else { continue }
                            let json = String(line.dropFirst(6))
                            guard let jsonData = json.data(using: .utf8) else { continue }
                            if let chunk = try? JSONDecoder().decode(GeminiResponse.self, from: jsonData),
                               let textChunk = chunk.candidates.first?.content.parts.first?.text {
                                continuation.yield(textChunk)
                            }
                        }
                        continuation.finish()
                    } catch { continuation.finish(throwing: error) }
                }
            }
        }
    }
}

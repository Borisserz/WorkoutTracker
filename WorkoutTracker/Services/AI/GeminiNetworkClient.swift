import Foundation
import FirebaseAppCheck

// MARK: - Gemini Schema

public enum GeminiSchemaType: String, Codable, Sendable {
    case object = "OBJECT"
    case array = "ARRAY"
    case string = "STRING"
    case integer = "INTEGER"
    case number = "NUMBER"
    case boolean = "BOOLEAN"
}

public final class GeminiSchema: Codable, Sendable {
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

struct GeminiRequest: Codable, Sendable {
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

private struct GeminiResponse: Codable, Sendable {
    struct Candidate: Codable, Sendable {
        struct Content: Codable, Sendable {
            struct Part: Codable, Sendable { let text: String }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

// MARK: - Network client (через Cloud Function + App Check)

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
        guard var comps = URLComponents(string: functionURL) else { throw AILogicError.invalidURL }
        if stream { comps.queryItems = [URLQueryItem(name: "stream", value: "true")] }
        guard let url = comps.url else { throw AILogicError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await AppCheck.appCheck().token(forcingRefresh: false)
        request.setValue(token.token, forHTTPHeaderField: "X-Firebase-AppCheck")

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    func generateText(from requestBody: GeminiRequest) async throws -> String {
        let request = try await makeRequest(stream: false, body: requestBody)
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            throw AILogicError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: msg)
        }
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first?.text else { throw AILogicError.noDataReturned }
        return text
    }

    func streamText(from requestBody: GeminiRequest) async throws -> AsyncThrowingStream<String, Error> {
        let request = try await makeRequest(stream: true, body: requestBody)
        let (bytes, response) = try await urlSession.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AILogicError.invalidResponse
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

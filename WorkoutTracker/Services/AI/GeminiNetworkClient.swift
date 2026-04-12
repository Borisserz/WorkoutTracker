// ============================================================
// FILE: WorkoutTracker/Services/AI/GeminiNetworkClient.swift
// ============================================================

import Foundation

// MARK: - Gemini/Vertex API DTOs

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
    
    public init(type: GeminiSchemaType, properties: [String: GeminiSchema]? = nil, items: GeminiSchema? = nil, required: [String]? = nil, description: String? = nil) {
        self.type = type
        self.properties = properties
        self.items = items
        self.required = required
        self.description = description
    }
}

struct GeminiRequest: Codable, Sendable {
    struct Part: Codable, Sendable { let text: String }
    struct Content: Codable, Sendable { let role: String; let parts: [Part] }
    struct SystemInstruction: Codable, Sendable { let parts: [Part] }
    struct GenerationConfig: Codable, Sendable { let temperature: Double; let responseMimeType: String?; let responseSchema: GeminiSchema? }
    
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

// MARK: - Network Client

actor GeminiNetworkClient {
    private let urlSession: URLSession
    private let region = "us-central1"
    private let modelName = "gemini-2.5-flash"
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0 // ✅ Даем время для сборки JSON
        config.timeoutIntervalForResource = 120.0
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
    }
    
    private func getEndpointURL(isStreaming: Bool) async throws -> URL {
        let projectId = try await VertexAuthenticator.shared.getProjectId()
        let action = isStreaming ? "streamGenerateContent?alt=sse" : "generateContent"
        let urlString = "https://\(region)-aiplatform.googleapis.com/v1/projects/\(projectId)/locations/\(region)/publishers/google/models/\(modelName):\(action)"
        guard let url = URL(string: urlString) else { throw AILogicError.invalidURL }
        return url
    }
    
    /// Обычный запрос (возвращает целиком, нужно для JSON)
    func generateText(from requestBody: GeminiRequest) async throws -> String {
        let url = try await getEndpointURL(isStreaming: false)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let accessToken = try await VertexAuthenticator.shared.getValidAccessToken()
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try await MainActor.run { try JSONEncoder().encode(requestBody) }
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown Error"
            throw AILogicError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: errorText)
        }
        
        let geminiResponse = try await MainActor.run { try JSONDecoder().decode(GeminiResponse.self, from: data) }
        guard let aiContent = geminiResponse.candidates.first?.content.parts.first?.text else { throw AILogicError.noDataReturned }
        return aiContent
    }
    
    /// ✅ ПОТОКОВЫЙ ЗАПРОС (STREAMING) ДЛЯ ЧАТА
    func streamText(from requestBody: GeminiRequest) async throws -> AsyncThrowingStream<String, Error> {
        let url = try await getEndpointURL(isStreaming: true)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let accessToken = try await VertexAuthenticator.shared.getValidAccessToken()
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try await MainActor.run { try JSONEncoder().encode(requestBody) }
        let (bytes, response) = try await urlSession.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AILogicError.invalidResponse
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        guard let jsonData = jsonString.data(using: .utf8) else { continue }
                        
                        if let chunkResponse = try? JSONDecoder().decode(GeminiResponse.self, from: jsonData),
                           let textChunk = chunkResponse.candidates.first?.content.parts.first?.text {
                            continuation.yield(textChunk)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

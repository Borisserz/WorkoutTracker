//
//  GeminiNetworkClient.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 3.04.26.
//

// ============================================================
// FILE: WorkoutTracker/ai_agent/GeminiNetworkClient.swift
// ============================================================

import Foundation

// MARK: - Gemini API DTOs (Изолированы здесь, чтобы не загрязнять бизнес-логику)

struct GeminiRequest: Codable, Sendable {
    struct Part: Codable, Sendable { let text: String }
    struct Content: Codable, Sendable { let role: String; let parts: [Part] }
    struct SystemInstruction: Codable, Sendable { let parts: [Part] }
    struct GenerationConfig: Codable, Sendable { let temperature: Double; let responseMimeType: String? }
    
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

/// Клиент, отвечающий исключительно за доставку данных до Gemini API и обратно.
actor GeminiNetworkClient {
    private let urlSession: URLSession
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 60.0
        self.urlSession = URLSession(configuration: config)
    }
    
    private func getEndpointURL() throws -> URL {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(cleanKey)"
        
        guard let url = URL(string: urlString) else {
            throw AILogicError.invalidURL
        }
        return url
    }
    
    /// Выполняет HTTP-запрос и возвращает чистый текст ответа ИИ
    func generateText(from requestBody: GeminiRequest) async throws -> String {
        var request = URLRequest(url: try getEndpointURL())
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Кодируем безопасно
        request.httpBody = try await MainActor.run {
            try JSONEncoder().encode(requestBody)
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AILogicError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let rawError = String(data: data, encoding: .utf8) ?? "Unknown HTTP Error"
            throw AILogicError.apiError(statusCode: httpResponse.statusCode, message: rawError)
        }
        
        do {
            let geminiResponse = try await MainActor.run {
                try JSONDecoder().decode(GeminiResponse.self, from: data)
            }
            guard let aiContent = geminiResponse.candidates.first?.content.parts.first?.text else {
                throw AILogicError.noDataReturned
            }
            return aiContent
        } catch {
            throw AILogicError.decodingFailed(error)
        }
    }
}

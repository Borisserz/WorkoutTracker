//
//  AILogicService.swift
//  WorkoutTracker
//

import Foundation

// MARK: - App DTOs

public struct InWorkoutResponseDTO: Codable, Sendable {
    let explanation: String
    let actionType: String // "dropWeight", "addSet", "replaceExercise", "none"
    let targetExerciseName: String?
    let valuePercentage: Double?
    let valueReps: Int?
    let valueWeightKg: Double?
    let replacementExerciseName: String?
}

public struct UserProfileContext: Codable, Sendable {
    let weightKg: Double
    let experienceLevel: String
    let favoriteMuscles: [String]
    let recentPRs: [String: Double]
    let language: String
    
    public init(weightKg: Double, experienceLevel: String, favoriteMuscles: [String] = [], recentPRs: [String: Double] = [:], language: String = "English") {
        self.weightKg = weightKg
        self.experienceLevel = experienceLevel
        self.favoriteMuscles = favoriteMuscles
        self.recentPRs = recentPRs
        self.language = language
    }
}

public struct GeneratedWorkoutDTO: Codable, Sendable {
    let title: String
    let aiMessage: String
    let exercises: [GeneratedExerciseDTO]
}

public struct GeneratedExerciseDTO: Codable, Sendable {
    let name: String
    let muscleGroup: String
    let type: String
    let sets: Int
    let reps: Int
    let recommendedWeightKg: Double?
    let restSeconds: Int?
}

public enum AILogicError: Error, LocalizedError, Sendable {
    case invalidURL, invalidResponse, noDataReturned
    case apiError(statusCode: Int, message: String)
    case decodingFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided is invalid or contains unsupported characters."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .noDataReturned:
            return "No data was returned from the server."
        case .apiError(let statusCode, let message):
            return "API Error (Status \(statusCode)): \(message)"
        case .decodingFailed(let error):
            return "Failed to decode the response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Gemini API Private Models

private struct GeminiRequest: Codable {
    struct Part: Codable { let text: String }
    struct Content: Codable { let role: String; let parts: [Part] }
    struct SystemInstruction: Codable { let parts: [Part] }
    struct GenerationConfig: Codable { let temperature: Double; let responseMimeType: String? }
    
    let systemInstruction: SystemInstruction?
    let contents: [Content]
    let generationConfig: GenerationConfig
}

private struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable { let text: String }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

// MARK: - Service
public actor AILogicService {
    private let urlSession: URLSession
    
    // ИСПОЛЬЗУЕМ МОДЕЛЬ GEMINI
    private let modelName = "gemini-pro"
    private let apiKey: String
    
    public init(apiKey: String, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
    }
    
    private func getGeminiURL() throws -> URL {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        // ИСПОЛЬЗУЕМ gemini-2.5-flash
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(cleanKey)"
        
        guard let url = URL(string: urlString) else {
            throw AILogicError.invalidURL
        }
        
        return url
    }
    
    // --- 1. ДЛЯ ГЕНЕРАЦИИ НОВОЙ ТРЕНИРОВКИ ---
    public func generateWorkoutPlan(userRequest: String, userProfile: UserProfileContext) async throws -> GeneratedWorkoutDTO {
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: createSystemPrompt(language: userProfile.language))]),
            contents: [.init(role: "user", parts: [.init(text: createUserPrompt(request: userRequest, profile: userProfile))])],
            generationConfig: .init(temperature: 0.7, responseMimeType: "application/json") // Принудительно просим JSON
        )
        
        let responseText = try await performRequest(requestBody)
        return try parseGeneratedWorkout(from: responseText)
    }
    
    // --- 2. ДЛЯ СОВЕТОВ ВО ВРЕМЯ ТРЕНИРОВКИ ---
    public func analyzeActiveWorkout(userMessage: String, workoutContext: String) async throws -> InWorkoutResponseDTO {
        let systemPrompt = """
        You are an elite In-Workout AI Coach. The user is currently mid-workout and needs immediate advice.
        Read the workout context and user message. 
        Provide a JSON response with an encouraging explanation and an optional command to modify the workout.
        
        RULES:
        1. Return ONLY pure JSON.
        2. "actionType" MUST be one of: "dropWeight", "addSet", "replaceExercise", "none".
        3. If "none", leave other value fields null.
        4. "valuePercentage" is for dropWeight (e.g., 10.0 for 10%).
        
        JSON SCHEMA:
        {
          "explanation": "String",
          "actionType": "String",
          "targetExerciseName": "String or null",
          "valuePercentage": Double or null,
          "valueReps": Int or null,
          "valueWeightKg": Double or null,
          "replacementExerciseName": "String or null"
        }
        """
        
        let userPrompt = """
        WORKOUT CONTEXT:
        \(workoutContext)
        
        USER MESSAGE:
        "\(userMessage)"
        """
        
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userPrompt)])],
            generationConfig: .init(temperature: 0.5, responseMimeType: "application/json")
        )
        
        let responseText = try await performRequest(requestBody)
        
        var text = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") { text = String(text.dropFirst(7)) }
        else if text.hasPrefix("```") { text = String(text.dropFirst(3)) }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = text.data(using: .utf8) else { throw AILogicError.noDataReturned }
        do {
            return try JSONDecoder().decode(InWorkoutResponseDTO.self, from: jsonData)
        } catch {
            throw AILogicError.decodingFailed(error)
        }
    }

    // --- 3. ДЛЯ ЕЖЕНЕДЕЛЬНОГО РЕВЬЮ (SPRINT 4) ---
    public func generatePerformanceReview(statsContext: String, language: String) async throws -> String {
        let systemPrompt = """
        You are an elite AI Data Analyst and Personal Trainer. 
        The user wants a weekly performance review based on their stats.
        
        RULES:
        1. Write a highly motivational, structured response using Markdown.
        2. Use headings (##), bold text (**), bullet points (*), and relevant emojis.
        3. Highlight their volume, workouts count, and any new PRs.
        4. Gently point out weak areas if they exist, and give 1-2 actionable tips for next week.
        5. RESPOND ENTIRELY IN \(language.uppercased()).
        6. Return standard text (NOT JSON). Do not use ```markdown blocks.
        """
        
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "Here are my stats:\n\(statsContext)")])],
            generationConfig: .init(temperature: 0.7, responseMimeType: nil) // Здесь JSON НЕ нужен, нужен просто Markdown текст
        )
        
        return try await performRequest(requestBody)
    }
    
    // --- PRIVATE NETWORK ENGINE ---
    
    private func performRequest(_ requestBody: GeminiRequest) async throws -> String {
        var request = URLRequest(url: try getGeminiURL())
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { throw AILogicError.invalidResponse }
        
        let rawResponseString = String(data: data, encoding: .utf8) ?? "Unable to decode response data"
        print("🌐 AILogicService | HTTP Status Code: \(httpResponse.statusCode)")
        print("🌐 AILogicService | Raw Response: \(rawResponseString)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AILogicError.apiError(statusCode: httpResponse.statusCode, message: rawResponseString)
        }
        
        do {
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let aiContent = geminiResponse.candidates.first?.content.parts.first?.text else {
                throw AILogicError.noDataReturned
            }
            return aiContent
        } catch {
            throw AILogicError.decodingFailed(error)
        }
    }
    
    // --- PRIVATE PROMPT HELPERS ---
    
    private func createSystemPrompt(language: String) -> String {
        return """
        You are an elite AI Personal Trainer. Generate a safe, effective workout plan.
        RESPOND ENTIRELY IN \(language.uppercased()).
        
        RULES:
        1. Return ONLY pure JSON matching the schema. No markdown blocks like ```json.
        2. "muscleGroup" MUST BE exactly one of: Chest, Back, Legs, Shoulders, Arms, Core, Cardio.
        3. "type" MUST BE exactly one of: Strength, Cardio, Duration.
        
        JSON SCHEMA:
        {
          "title": "String",
          "aiMessage": "String (Motivational summary)",
          "exercises": [
            {
              "name": "String",
              "muscleGroup": "String",
              "type": "String",
              "sets": Int,
              "reps": Int,
              "recommendedWeightKg": Double (or null),
              "restSeconds": Int
            }
          ]
        }
        """
    }
    
    private func createUserPrompt(request: String, profile: UserProfileContext) -> String {
        let prsString = profile.recentPRs.isEmpty ? "None" : profile.recentPRs.map { "\($0.key): \($0.value) kg" }.joined(separator: ", ")
        return """
        USER PROFILE:
        Weight: \(profile.weightKg) kg
        Experience: \(profile.experienceLevel)
        Recent PRs: \(prsString)
        
        REQUEST: "\(request)"
        """
    }
    
    private func parseGeneratedWorkout(from rawContent: String) throws -> GeneratedWorkoutDTO {
        var text = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") { text = String(text.dropFirst(7)) }
        else if text.hasPrefix("```") { text = String(text.dropFirst(3)) }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = text.data(using: .utf8) else { throw AILogicError.noDataReturned }
        do {
            return try JSONDecoder().decode(GeneratedWorkoutDTO.self, from: jsonData)
        } catch {
            throw AILogicError.decodingFailed(error)
        }
    }
}

// ============================================================
// FILE: WorkoutTracker/ai_agent/AILogicService.swift
// ============================================================

import Foundation

public enum AILogicError: Error, LocalizedError, Sendable {
    case invalidURL, invalidResponse, noDataReturned, invalidData, friendlyError
    case apiError(statusCode: Int, message: String)
    case decodingFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL provided is invalid."
        case .invalidResponse: return "Received an invalid response from the server."
        case .noDataReturned: return "No data was returned from the server."
        case .invalidData: return "The AI response was malformed."
        case .friendlyError: return "Прости, я немного запутался. Можешь перефразировать запрос?"
        case .apiError(let code, let msg): return "API Error (\(code)): \(msg)"
        case .decodingFailed(let err): return "Decoding failed: \(err.localizedDescription)"
        }
    }
}

// MARK: - Service

/// Бизнес-логика ИИ. Отвечает только за промпты и парсинг наших DTO.
public actor AILogicService {
    
    // Внедряем сетевой клиент
    private let networkClient: GeminiNetworkClient
    
    init(networkClient: GeminiNetworkClient) {
        self.networkClient = networkClient
    }
    
    // --- ДЛЯ ГЕНЕРАЦИИ НАЗВАНИЯ ЧАТА ---
    public func generateChatTitle(for userMessage: String) async throws -> String {
        let systemPrompt = "Придумай очень краткое название (максимум 3-4 слова) для чата о фитнесе, который начинается с запроса пользователя. Верни только текст названия без кавычек и лишних символов."
        
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userMessage)])],
            generationConfig: .init(temperature: 0.7, responseMimeType: "text/plain")
        )
        let response = try await networkClient.generateText(from: requestBody)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // --- 1. ДЛЯ ГЕНЕРАЦИИ ОТВЕТА / НОВОЙ ТРЕНИРОВКИ ---
    public func generateWorkoutPlan(userRequest: String, userProfile: UserProfileContext) async throws -> AICoachResponseDTO {
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: createSystemPrompt(language: userProfile.language, tone: userProfile.aiCoachTone, weightUnit: userProfile.weightUnit, availableExercises: userProfile.availableExercises))]),
            contents: [.init(role: "user", parts: [.init(text: createUserPrompt(request: userRequest, profile: userProfile))])],
            generationConfig: .init(temperature: 0.5, responseMimeType: "application/json")
        )
        
        let responseText = try await networkClient.generateText(from: requestBody)
        return try await parseCoachResponse(from: responseText)
    }
    
    // --- 2. ДЛЯ СОВЕТОВ ВО ВРЕМЯ ТРЕНИРОВКИ ---
    public func analyzeActiveWorkout(userMessage: String, workoutContext: String, catalogContext: String, tone: String, weightUnit: String) async throws -> InWorkoutResponseDTO {
        let isRussian = Locale.current.language.languageCode?.identifier == "ru"
        let langInstruction = isRussian ? "ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ, НО НАЗВАНИЯ УПРАЖНЕНИЙ ОСТАВЛЯЙ НА АНГЛИЙСКОМ!" : "REPLY STRICTLY IN ENGLISH!"

        let systemPrompt = """
        You are an elite AI Strength Coach. 
        \(langInstruction)
        
        ПРАВИЛА:
        1. YOU MUST ALWAYS RETURN A VALID JSON OBJECT.
        2. All weight values MUST be in \(weightUnit).
        3. "explanation" — твой ответ НА РУССКОМ.
        4. Если тренировка ЗАВЕРШЕНА, "actionType" ВСЕГДА должен быть "none".
        5. "actionType" ДОЛЖЕН БЫТЬ одним из: replaceExercise, dropWeight, reduceRemainingLoad, skipExercise, addSet, none.
        
        ДОСТУПНЫЕ УПРАЖНЕНИЯ ДЛЯ ЗАМЕНЫ:
        \(catalogContext)
        """
        
        let userPrompt = "WORKOUT CONTEXT:\n\(workoutContext)\n\nUSER MESSAGE:\n\"\(userMessage)\""
        
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userPrompt)])],
            generationConfig: .init(temperature: 0.3, responseMimeType: "application/json")
        )
        
        let responseText = try await networkClient.generateText(from: requestBody)
        var text = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") { text = String(text.dropFirst(7)) }
        else if text.hasPrefix("```") { text = String(text.dropFirst(3)) }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        
        guard let jsonData = text.data(using: .utf8) else { throw AILogicError.noDataReturned }
        
        return try await MainActor.run {
            try JSONDecoder().decode(InWorkoutResponseDTO.self, from: jsonData)
        }
    }

    // --- 3. ДЛЯ ЕЖЕНЕДЕЛЬНОГО РЕВЬЮ ---
    public func generatePerformanceReview(statsContext: String, language: String) async throws -> String {
        let isRussian = language == "Russian"
        let systemPrompt: String
        let userStatsHeader: String
        
        if isRussian {
            systemPrompt = "Ты — элитный аналитик. Напиши мотивационный обзор в Markdown. ОТВЕЧАЙ НА РУССКОМ. Не используй блоки кода ```markdown."
            userStatsHeader = "Вот моя статистика:"
        } else {
            systemPrompt = "You are an elite data analyst. Write a motivational review in Markdown. REPLY IN ENGLISH. Do not use code blocks like ```markdown."
            userStatsHeader = "Here are my statistics:"
        }
        
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "\(userStatsHeader)\n\(statsContext)")])],
            generationConfig: .init(temperature: 0.7, responseMimeType: nil)
        )
        
        return try await networkClient.generateText(from: requestBody)
    }
    
    // --- PRIVATE PROMPT HELPERS ---
    private func createSystemPrompt(language: String, tone: String, weightUnit: String, availableExercises: [String]) -> String {
        var prompt = "ALWAYS RETURN VALID JSON. Weights must be in \(weightUnit).\n"
        if language == "Russian" { prompt += "ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ.\n" }
        if !availableExercises.isEmpty { prompt += "AVAILABLE EXERCISES:\n\(availableExercises.joined(separator: ", "))" }
        return prompt
    }
    
    private func createUserPrompt(request: String, profile: UserProfileContext) -> String {
        return "ПРОФИЛЬ: Вес: \(profile.weightKg)\nЗАПРОС: \"\(request)\""
    }
    
    private func parseCoachResponse(from rawContent: String) async throws -> AICoachResponseDTO {
        let text = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let startIndex = text.firstIndex(of: "{"), let endIndex = text.lastIndex(of: "}") else {
            throw AILogicError.invalidData
        }
        
        let jsonString = String(text[startIndex...endIndex])
        guard let jsonData = jsonString.data(using: .utf8) else { throw AILogicError.noDataReturned }
        
        do {
            let workoutDTO = try await MainActor.run {
                try JSONDecoder().decode(GeneratedWorkoutDTO.self, from: jsonData)
            }
            if workoutDTO.exercises.isEmpty && workoutDTO.title.isEmpty {
                return AICoachResponseDTO(text: workoutDTO.aiMessage, workout: nil)
            }
            return AICoachResponseDTO(text: workoutDTO.aiMessage, workout: workoutDTO)
        } catch {
            throw AILogicError.friendlyError
        }
    }
}

extension AILogicService {
    
    public func generateFormRoast(exercise: String, reps: Int, language: String) async throws -> String {
        let isRussian = language == "Russian"
        let langInstruction = isRussian ? "ОТВЕЧАЙ НА РУССКОМ." : "REPLY IN ENGLISH."
        
        let systemPrompt = """
        You are a savage, sarcastic, and extremely funny AI gym bro coach. 
        Your goal is to ROAST the user's workout form and performance.
        Keep it PG-13, but be absolutely merciless and funny. Use gym slang.
        Do NOT use markdown. Maximum 3 short sentences.
        \(langInstruction)
        """
        
        let userPrompt = "I just did \(reps) reps of \(exercise). Roast my form and effort."
        
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userPrompt)])],
            generationConfig: .init(temperature: 0.9, responseMimeType: "text/plain") // Higher temp for more creativity
        )
        
        let response = try await networkClient.generateText(from: requestBody)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

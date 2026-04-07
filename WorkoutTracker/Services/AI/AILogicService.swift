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
extension AILogicService {
    
    // --- 4. FOR MULTI-DAY PROGRAM GENERATION ---
    public func generateMultiDayProgram(
        goal: String,
        level: String,
        days: Int,
        equipment: String,
        musclesToGrow: [String],
        musclesToExclude: [String]
    ) async throws -> GeneratedProgramDTO {
        
        let systemPrompt = """
        You are an elite AI Strength & Conditioning Architect.
        Design a premium multi-day workout program based on the user's parameters.
        
        RULES:
        1. YOU MUST RETURN ONLY A RAW, VALID JSON OBJECT. NO markdown formatting, NO ```json wrappers, NO explanations.
        2. Create EXACTLY \(days) workout days in the "schedule" array.
        3. Goal: \(goal). Experience Level: \(level). Available Equipment: \(equipment).
        4. FOCUS HEAVILY on growing these muscles: \(musclesToGrow.isEmpty ? "None specified" : musclesToGrow.joined(separator: ", ")).
        5. COMPLETELY EXCLUDE exercises targeting these muscles (e.g., due to injury): \(musclesToExclude.isEmpty ? "None specified" : musclesToExclude.joined(separator: ", ")).
        6. Use standard exercise names from the catalog.
        7. Provide appropriate sets, reps, and restSeconds for the goal.
        
        JSON STRUCTURE:
        {
          "title": "Program Name",
          "description": "Short motivational description",
          "durationWeeks": 4,
          "schedule": [
            {
              "dayName": "Day 1",
              "focus": "Chest & Triceps",
              "exercises": [
                {
                  "name": "Bench Press",
                  "muscleGroup": "Chest",
                  "type": "Strength",
                  "sets": 4,
                  "reps": 8,
                  "recommendedWeightKg": null,
                  "restSeconds": 90
                }
              ]
            }
          ]
        }
        """
        
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "Generate my \(days)-day program.")])],
            generationConfig: .init(temperature: 0.4, responseMimeType: "application/json")
        )
        
        let responseText = try await networkClient.generateText(from: requestBody)
        var text = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") { text = String(text.dropFirst(7)) }
        else if text.hasPrefix("```") { text = String(text.dropFirst(3)) }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        
        guard let jsonData = text.data(using: .utf8) else { throw AILogicError.noDataReturned }
        
        do {
            return try await MainActor.run {
                try JSONDecoder().decode(GeneratedProgramDTO.self, from: jsonData)
            }
        } catch {
            print("Decoding Error: \(error)")
            throw AILogicError.invalidData
        }
    }
}
// В файл: WorkoutTracker/Services/AI/AILogicService.swift
extension AILogicService {
    public func processSmartAction(
        commandType: String,
        workoutContext: String,
        catalogContext: String,
        weightUnit: String
    ) async throws -> SmartActionDTO {
        
        let systemPrompt = """
        Ты — элитный AI-тренер. Твоя задача — мгновенно корректировать текущую тренировку по запросу.
        
        ПРАВИЛА ОТВЕТА (ТОЛЬКО JSON):
        1. "action": тип действия ("swap", "reduce_weight", "increase_weight", "add_finisher").
        2. "exerciseName": название целевого упражнения (СТРОГО ИЗ КАТАЛОГА НА АНГЛИЙСКОМ).
        3. "setsRemaining": количество оставшихся сетов (integer).
        4. "weightValue": новый рабочий вес (double) в \(weightUnit). Если переход со штанги на гантели — снижай вес на 15-20%. Если "Too Heavy" - снижай на 10%.
        5. "reasoning": короткая дерзкая фраза НА РУССКОМ для голосового ассистента (макс 2 предложения). Пример: "Тренажер занят? Не беда, сделаем жим гантелей. Бери по 30 килограмм и погнали!"
        
        ДОСТУПНЫЕ УПРАЖНЕНИЯ:
        \(catalogContext)
        """
        
        let userPrompt = "Текущий статус тренировки:\n\(workoutContext)\n\nКоманда пользователя: \(commandType)"
        
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
            try JSONDecoder().decode(SmartActionDTO.self, from: jsonData)
        }
    }
}

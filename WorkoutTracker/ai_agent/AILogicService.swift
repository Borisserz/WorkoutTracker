//
//  AILogicService.swift
//  WorkoutTracker
//

import Foundation

// MARK: - App DTOs

public struct AICoachResponseDTO: Sendable {
    let text: String
    let workout: GeneratedWorkoutDTO?
}

public struct InWorkoutResponseDTO: Codable, Sendable {
    let explanation: String
    let actionType: String // "dropWeight", "addSet", "replaceExercise", "skipExercise", "reduceRemainingLoad", "none"
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
    let workoutsThisWeek: Int
    let currentStreak: Int
    let fatiguedMuscles: [String]
    let availableExercises: [String]
    let aiCoachTone: String
    let weightUnit: String
    
    public init(weightKg: Double, experienceLevel: String, favoriteMuscles: [String] = [], recentPRs: [String: Double] = [:], language: String = "English", workoutsThisWeek: Int = 0, currentStreak: Int = 0, fatiguedMuscles: [String] = [], availableExercises: [String] = [], aiCoachTone: String = "Мотивационный", weightUnit: String = "kg") {
        self.weightKg = weightKg
        self.experienceLevel = experienceLevel
        self.favoriteMuscles = favoriteMuscles
        self.recentPRs = recentPRs
        self.language = language
        self.workoutsThisWeek = workoutsThisWeek
        self.currentStreak = currentStreak
        self.fatiguedMuscles = fatiguedMuscles
        self.availableExercises = availableExercises
        self.aiCoachTone = aiCoachTone
        self.weightUnit = weightUnit
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
    case invalidData
    case friendlyError
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
        case .invalidData:
            return "The AI response was malformed or missing valid JSON."
        case .friendlyError:
            return "Прости, я немного запутался. Можешь перефразировать запрос?"
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
    private let apiKey: String
    
    public init(apiKey: String) {
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 60.0
        self.urlSession = URLSession(configuration: config)
    }
    
    private func getGeminiURL() throws -> URL {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(cleanKey)"
        
        guard let url = URL(string: urlString) else {
            throw AILogicError.invalidURL
        }
        
        return url
    }
    
    // --- ДЛЯ ГЕНЕРАЦИИ НАЗВАНИЯ ЧАТА ---
    public func generateChatTitle(for userMessage: String) async throws -> String {
        let systemPrompt = "Придумай очень краткое название (максимум 3-4 слова) для чата о фитнесе, который начинается с запроса пользователя. Верни только текст названия без кавычек и лишних символов."
        
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userMessage)])],
            generationConfig: .init(temperature: 0.7, responseMimeType: "text/plain")
        )
        let response = try await performRequest(requestBody)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // --- 1. ДЛЯ ГЕНЕРАЦИИ ОТВЕТА / НОВОЙ ТРЕНИРОВКИ ---
    public func generateWorkoutPlan(userRequest: String, userProfile: UserProfileContext) async throws -> AICoachResponseDTO {
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: createSystemPrompt(language: userProfile.language, tone: userProfile.aiCoachTone, weightUnit: userProfile.weightUnit, availableExercises: userProfile.availableExercises))]),
            contents: [.init(role: "user", parts: [.init(text: createUserPrompt(request: userRequest, profile: userProfile))])],
            generationConfig: .init(temperature: 0.5, responseMimeType: "application/json")
        )
        
        let responseText = try await performRequest(requestBody)
        return try parseCoachResponse(from: responseText)
    }
    
    // --- 2. ДЛЯ СОВЕТОВ ВО ВРЕМЯ ТРЕНИРОВКИ ---
    public func analyzeActiveWorkout(userMessage: String, workoutContext: String, catalogContext: String, tone: String, weightUnit: String) async throws -> InWorkoutResponseDTO {
        let personality: String
        switch tone {
        case "Строгий": personality = "Твой стиль: Строгий армейский инструктор. Требуешь полной отдачи."
        case "Дружелюбный": personality = "Твой стиль: Заботливый фитнес-наставник. Хвалишь за усилия."
        case "Научный": personality = "Твой стиль: Профессор биомеханики. Используешь научную терминологию."
        default: personality = "Твой стиль: Мотивационный тренер. Вдохновляешь и заряжаешь."
        }
        
        let systemPrompt = """
        Ты — элитный ИИ-тренер. Учитывай статус тренировки (ACTIVE WORKOUT или COMPLETED WORKOUT).
        \(personality)
        ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ, НО НАЗВАНИЯ УПРАЖНЕНИЙ ОСТАВЛЯЙ НА АНГЛИЙСКОМ!
        
        ПРАВИЛА:
        1. YOU MUST ALWAYS RETURN A VALID JSON OBJECT. No markdown, no conversational text outside JSON.
        2. All weight values MUST be in \(weightUnit).
        3. "explanation" — твой ответ НА РУССКОМ.
        4. Если тренировка ЗАВЕРШЕНА (COMPLETED WORKOUT), "actionType" ВСЕГДА должен быть "none".
        5. "actionType" ДОЛЖЕН БЫТЬ одним из:
           - "replaceExercise" (ВАЖНО: "replacementExerciseName" БРАТЬ ТОЛЬКО ИЗ КАТАЛОГА В КОНТЕКСТЕ)
           - "dropWeight" (снизить вес)
           - "reduceRemainingLoad" (снизить веса на все оставшиеся подходы, процент в valuePercentage)
           - "skipExercise" (удалить/пропустить упражнение)
           - "addSet" (добавить подход)
           - "none" (обычный разговор/аналитика/похвала)
        
        ДОСТУПНЫЕ УПРАЖНЕНИЯ ДЛЯ ЗАМЕНЫ:
        \(catalogContext)
        
        ПРИМЕР JSON ДЛЯ ЗАМЕНЫ:
        {
          "explanation": "Давай заменим Bench Press на Dumbbell Press, это снимет нагрузку со связок.",
          "actionType": "replaceExercise",
          "targetExerciseName": "Bench Press",
          "valuePercentage": null,
          "valueReps": 10,
          "valueWeightKg": null,
          "replacementExerciseName": "Dumbbell Press"
        }
        """
        
        let userPrompt = "WORKOUT CONTEXT:\n\(workoutContext)\n\nUSER MESSAGE:\n\"\(userMessage)\""
        
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userPrompt)])],
            generationConfig: .init(temperature: 0.3, responseMimeType: "application/json")
        )
        
        let responseText = try await performRequest(requestBody)
        var text = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") { text = String(text.dropFirst(7)) }
        else if text.hasPrefix("```") { text = String(text.dropFirst(3)) }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        
        guard let jsonData = text.data(using: .utf8) else { throw AILogicError.noDataReturned }
        do {
            return try JSONDecoder().decode(InWorkoutResponseDTO.self, from: jsonData)
        } catch {
            print("❌ AI analyzeActiveWorkout decode error: \(error)")
            throw AILogicError.friendlyError
        }
    }

    // --- 3. ДЛЯ ЕЖЕНЕДЕЛЬНОГО РЕВЬЮ ---
    public func generatePerformanceReview(statsContext: String, language: String) async throws -> String {
        let systemPrompt = """
        Ты — элитный аналитик данных и фитнес-тренер.
        Пользователь просит еженедельный обзор его результатов на основе предоставленной статистики.
        ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ.
        
        ПРАВИЛА:
        1. Напиши очень мотивационный, структурированный ответ используя Markdown.
        2. Используй заголовки (##), жирный текст (**), маркированные списки (*) и эмодзи.
        3. Выдели объем поднятого веса, количество тренировок и личные рекорды (PRs).
        4. Мягко укажи на отстающие группы мышц (если они есть) и дай 1-2 практических совета на следующую неделю.
        5. Не используй блоки кода ```markdown. Выдавай просто отформатированный текст.
        """
        
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "Вот моя статистика:\n\(statsContext)")])],
            generationConfig: .init(temperature: 0.7, responseMimeType: nil)
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
    private func createSystemPrompt(language: String, tone: String, weightUnit: String, availableExercises: [String]) -> String {
        
        let personality: String
        switch tone {
        case "Строгий":
            personality = "Твой стиль общения: Строгий армейский инструктор. Требуешь полной отдачи."
        case "Дружелюбный":
            personality = "Твой стиль общения: Добрый и заботливый фитнес-наставник. Хвалишь за усилия."
        case "Научный":
            personality = "Твой стиль общения: Профессор биомеханики. Оперируешь научными фактами."
        default:
            personality = "Твой стиль общения: Энергичный тренер. Вдохновляешь и заряжаешь позитивом."
        }
        
        var prompt = """
        Ты — элитный ИИ-фитнес-тренер. 
        \(personality) Поддерживай эту роль в каждом сообщении!
        Твоя задача — общаться с пользователем СТРОГО НА РУССКОМ ЯЗЫКЕ.
        
        ПРАВИЛА:
        1. YOU MUST ALWAYS RETURN A VALID JSON OBJECT. NO RAW TEXT OUTSIDE JSON. No markdown tags like ```json.
        2. Твой ответ пользователю (совет, приветствие и т.д.) ДОЛЖЕН БЫТЬ в поле "aiMessage" внутри JSON.
        3. ТОЛЬКО ЕСЛИ пользователь просит составить план тренировки, заполни поля "title" и "exercises". Если план не нужен, оставь "title" пустым ("") и "exercises" пустым массивом [].
        4. КРИТИЧЕСКИ ВАЖНО: Имена упражнений (поле "name" в JSON) ДОЛЖНЫ быть точной копией из переданного списка "ДОСТУПНЫЕ УПРАЖНЕНИЯ". Не переводи их на русский!
        5. "muscleGroup": Chest, Back, Legs, Shoulders, Arms, Core, Cardio. (Строго на английском).
        6. "type": Strength, Cardio, Duration. (Строго на английском).
        7. All weight values in JSON MUST be in \(weightUnit). Do not use any other metric.
        8. Избегай перетренированности уставших мышц (<50% восстановления).
        9. Не спамь статистикой, если пользователь об этом не спрашивает.
        """
        
        if !availableExercises.isEmpty {
            prompt += "\n\nДОСТУПНЫЕ УПРАЖНЕНИЯ:\n\(availableExercises.joined(separator: ", "))"
        }
        
        prompt += """
        
        ПРИМЕР ФОРМАТА JSON:
        {
          "title": "Мощная Тренировка",
          "aiMessage": "Отличный выбор! Я подобрал идеальные упражнения для твоего восстановления.",
          "exercises": [
            {
              "name": "Bench Press",
              "muscleGroup": "Chest",
              "type": "Strength",
              "sets": 3,
              "reps": 10,
              "recommendedWeightKg": 60.0,
              "restSeconds": 90
            }
          ]
        }
        """
        
        return prompt
    }
        
    private func createUserPrompt(request: String, profile: UserProfileContext) -> String {
        let prsString = profile.recentPRs.isEmpty ? "Нет" : profile.recentPRs.map { "\($0.key): \($0.value) \(profile.weightUnit)" }.joined(separator: ", ")
        
        var prompt = """
        ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        Вес: \(profile.weightKg) \(profile.weightUnit)
        Опыт: \(profile.experienceLevel)
        Тренировок на этой неделе: \(profile.workoutsThisWeek)
        Текущий стрик: \(profile.currentStreak) дней
        Недавние рекорды: \(prsString)
        """
        
        if !profile.fatiguedMuscles.isEmpty {
            prompt += "\nУставшие мышцы (<50% восстановления): \(profile.fatiguedMuscles.joined(separator: ", "))"
        }
        
        prompt += "\n\nЗАПРОС ПОЛЬЗОВАТЕЛЯ: \"\(request)\""
        return prompt
    }
    
    // --- ПАРСЕР СТРОГОГО JSON ОТВЕТА ---
    private func parseCoachResponse(from rawContent: String) throws -> AICoachResponseDTO {
        var text = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") { text = String(text.dropFirst(7)) }
        else if text.hasPrefix("```") { text = String(text.dropFirst(3)) }
        if text.hasSuffix("```") { text = String(text.dropLast(3)) }
        
        guard let jsonData = text.data(using: .utf8) else { throw AILogicError.noDataReturned }
        
        do {
            let workoutDTO = try JSONDecoder().decode(GeneratedWorkoutDTO.self, from: jsonData)
            if workoutDTO.exercises.isEmpty && (workoutDTO.title.isEmpty || workoutDTO.title == "") {
                return AICoachResponseDTO(text: workoutDTO.aiMessage, workout: nil)
            } else {
                return AICoachResponseDTO(text: workoutDTO.aiMessage, workout: workoutDTO)
            }
        } catch {
            print("❌ AI parseCoachResponse decode error: \(error)")
            throw AILogicError.friendlyError
        }
    }
}

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
    let workoutsThisWeek: Int
    let currentStreak: Int
    let fatiguedMuscles: [String]
    let availableExercises: [String]
    let aiCoachTone: String
    
    public init(weightKg: Double, experienceLevel: String, favoriteMuscles: [String] = [], recentPRs: [String: Double] = [:], language: String = "English", workoutsThisWeek: Int = 0, currentStreak: Int = 0, fatiguedMuscles: [String] = [], availableExercises: [String] = [], aiCoachTone: String = "Мотивационный") {
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
    case invalidData // 👈 ДОБАВЛЯЕМ ЭТОТ КЕЙС
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
    
    public init(apiKey: String, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
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
            systemInstruction: .init(parts: [.init(text: createSystemPrompt(language: userProfile.language, tone: userProfile.aiCoachTone))]),
            contents: [.init(role: "user", parts: [.init(text: createUserPrompt(request: userRequest, profile: userProfile))])],
            generationConfig: .init(temperature: 0.5, responseMimeType: nil)
        )
        
        let responseText = try await performRequest(requestBody)
        return try parseCoachResponse(from: responseText)
    }
    
    // --- 2. ДЛЯ СОВЕТОВ ВО ВРЕМЯ ТРЕНИРОВКИ ---
    public func analyzeActiveWorkout(userMessage: String, workoutContext: String, tone: String) async throws -> InWorkoutResponseDTO {
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
               Ответ должен быть СТРОГО в формате JSON без markdown блоков (```json).
               
               ПРАВИЛА:
               1. Верни ТОЛЬКО чистый JSON. 
               2. "explanation" — твой ответ НА РУССКОМ.
               3. Если тренировка ЗАВЕРШЕНА (COMPLETED WORKOUT), "actionType" ВСЕГДА должен быть "none".
               4. "actionType" ДОЛЖЕН БЫТЬ одним из:
                  - "replaceExercise" (заменить упражнение. ВАЖНО: "replacementExerciseName" БРАТЬ ТОЛЬКО ИЗ КАТАЛОГА В КОНТЕКСТЕ)
                  - "dropWeight" (снизить вес)
                  - "reduceRemainingLoad" (снизить веса на все оставшиеся подходы, процент в valuePercentage)
                  - "skipExercise" (удалить/пропустить упражнение)
                  - "addSet" (добавить подход)
                  - "none" (обычный разговор/аналитика)
               
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
                  generationConfig: .init(temperature: 0.3, responseMimeType: "application/json") // Температуру снизили для точного JSON
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
                  throw AILogicError.decodingFailed(error)
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
    
    private func createSystemPrompt(language: String, tone: String) -> String {
        
        let personality: String
        switch tone {
        case "Строгий":
            personality = "Твой стиль общения: Строгий армейский инструктор. Ты обращаешься к пользователю жестко, требуешь полной отдачи, не терпишь лени, используешь командный тон и минимум похвалы."
        case "Дружелюбный":
            personality = "Твой стиль общения: Добрый и заботливый фитнес-наставник. Ты общаешься мягко, как лучший друг, всегда хвалишь за усилия и заботишься о самочувствии."
        case "Научный":
            personality = "Твой стиль общения: Профессор биомеханики и спортивный врач. Ты используешь научную терминологию, объясняешь физиологические процессы (гипертрофия, ЦНС, метаболизм), оперируешь фактами и цифрами."
        default:
            personality = "Твой стиль общения: Энергичный и мотивационный тренер. Ты вдохновляешь пользователя, заряжаешь позитивом и уверенностью в своих силах."
        }
        
        return """
        Ты — элитный ИИ-фитнес-тренер. 
        \(personality) Поддерживай эту роль в каждом сообщении!
        Твоя задача — общаться с пользователем СТРОГО НА РУССКОМ ЯЗЫКЕ.
        
        ПРАВИЛА:
        1. Если пользователь задает общий вопрос или просит совета — отвечай в рамках своей роли обычным текстом. Не ставь эмодзи, если тебя явно не просят.
        2. ТОЛЬКО ЕСЛИ пользователь просит составить план тренировки, сгенерируй JSON внутри тегов [WORKOUT_JSON] и [/WORKOUT_JSON].
        3. КРИТИЧЕСКИ ВАЖНО: Имена упражнений (поле "name" в JSON) ДОЛЖНЫ быть точной копией (один в один) из переданного списка "ДОСТУПНЫЕ УПРАЖНЕНИЯ". Не переводи их на русский! Это сломает аналитику приложения. Пиши "Bench Press", а не "Жим лежа".
        4. "muscleGroup": Chest, Back, Legs, Shoulders, Arms, Core, Cardio. (Строго на английском).
        5. "type": Strength, Cardio, Duration. (Строго на английском).
        6. Избегай перетренированности уставших мышц (<50% восстановления).
        7. Не спамь статистикой (стрики, количество тренировок), если пользователь об этом прямо не спрашивает.
        
        ПРИМЕР JSON (Используй ТОЛЬКО этот формат с реальными цифрами и строками, без комментариев):
        [WORKOUT_JSON]
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
        [/WORKOUT_JSON]
        """
    }
        
    private func createUserPrompt(request: String, profile: UserProfileContext) -> String {
        let prsString = profile.recentPRs.isEmpty ? "Нет" : profile.recentPRs.map { "\($0.key): \($0.value) кг" }.joined(separator: ", ")
        
        var prompt = """
        ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        Вес: \(profile.weightKg) кг
        Опыт: \(profile.experienceLevel)
        Тренировок на этой неделе: \(profile.workoutsThisWeek)
        Текущий стрик: \(profile.currentStreak) дней
        Недавние рекорды: \(prsString)
        """
        
        if !profile.fatiguedMuscles.isEmpty {
            prompt += "\nУставшие мышцы (<50% восстановления): \(profile.fatiguedMuscles.joined(separator: ", "))"
        }
        
        // ПЕРЕДАЕМ БАЗУ УПРАЖНЕНИЙ ИИ
        if !profile.availableExercises.isEmpty {
            prompt += "\n\nДОСТУПНЫЕ УПРАЖНЕНИЯ (Выбирай упражнения для JSON ТОЛЬКО из этого списка. Копируй их названия символ в символ, НЕ ПЕРЕВОДИ НА РУССКИЙ!):\n"
            prompt += profile.availableExercises.joined(separator: ", ")
        }
        
        prompt += "\n\nЗАПРОС ПОЛЬЗОВАТЕЛЯ: \"\(request)\""
        return prompt
    }
    
    // --- ПАРСЕР ГИБРИДНОГО ОТВЕТА (Текст + возможный JSON в тегах) ---
    private func parseCoachResponse(from rawContent: String) throws -> AICoachResponseDTO {
        let startTag = "[WORKOUT_JSON]"
        let endTag = "[/WORKOUT_JSON]"
        
        // 1. Пытаемся найти контент между тегами
        if let startRange = rawContent.range(of: startTag),
           let endRange = rawContent.range(of: endTag) {
            
            let jsonString = String(rawContent[startRange.upperBound..<endRange.lowerBound])
            
            // 2. ИСПОЛЬЗУЕМ REGEX: Ищем первую { и последнюю }, игнорируя любой мусор от ИИ (```json и т.д.)
            guard let jsonStartIndex = jsonString.firstIndex(of: "{"),
                  let jsonEndIndex = jsonString.lastIndex(of: "}") else {
                throw AILogicError.invalidData // JSON не найден внутри тегов
            }
            
            let cleanJsonString = String(jsonString[jsonStartIndex...jsonEndIndex])
            guard let jsonData = cleanJsonString.data(using: .utf8) else {
                throw AILogicError.noDataReturned
            }
            
            do {
                let workoutDTO = try JSONDecoder().decode(GeneratedWorkoutDTO.self, from: jsonData)
                
                // Собираем разговорный текст до и после тегов
                let textBefore = String(rawContent[..<startRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let textAfter = String(rawContent[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let conversationalText = [textBefore, textAfter].filter { !$0.isEmpty }.joined(separator: "\n\n")
                let finalMessage = conversationalText.isEmpty ? workoutDTO.aiMessage : conversationalText
                
                return AICoachResponseDTO(text: finalMessage, workout: workoutDTO)
                
            } catch {
                throw AILogicError.decodingFailed(error)
            }
        } else {
            // Обычный разговорный ответ
            let cleanText = rawContent.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return AICoachResponseDTO(text: cleanText, workout: nil)
        }
    }
}

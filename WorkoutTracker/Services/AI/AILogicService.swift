//
//  AILogicService.swift
//  WorkoutTracker
//
//  [5.1.3] Privacy: body weight (Health data) is NEVER sent to the server.
//  System prompts rely on experience level + PRs only.
//

import Foundation

public enum AILogicError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case noDataReturned
    case invalidData
    case friendlyError
    case apiError(statusCode: Int, message: String)
    case decodingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:        return "The URL provided is invalid."
        case .invalidResponse:   return "Received an invalid response from the server."
        case .noDataReturned:    return "No data was returned from the server."
        case .invalidData:       return "The AI response was malformed."
        case .friendlyError:     return "Sorry, I got a little confused. Could you rephrase that?"
        case .apiError(let code, let msg):
            return "API Error (\(code)): \(msg)"
        case .decodingFailed(let err):
            return "Decoding failed: \(err.localizedDescription)"
        }
    }
}

private struct ChatNetworkResponse: Codable, Sendable {
    let aiMessage: String
    let hasWorkout: Bool
    let workoutTitle: String?
    let exercises: [GeneratedExerciseDTO]?
}

private struct RecoveryResponseDTO: Codable, Sendable {
    let recommendedHours: Double
}

public actor AILogicService {

    private let networkClient: GeminiNetworkClient

    init(networkClient: GeminiNetworkClient) {
        self.networkClient = networkClient
    }

    // MARK: - Schemas (nonisolated — GeminiSchema init is MainActor-bound,
    // so we mark these as nonisolated to keep the actor methods callable
    // without unnecessary main-actor hops for schema construction.)

    nonisolated private var exerciseSchema: GeminiSchema {
        GeminiSchema(type: .object, properties: [
            "name": GeminiSchema(type: .string),
            "muscleGroup": GeminiSchema(type: .string),
            "type": GeminiSchema(type: .string),
            "sets": GeminiSchema(type: .integer),
            "reps": GeminiSchema(type: .integer),
            "recommendedWeightKg": GeminiSchema(type: .number),
            "restSeconds": GeminiSchema(type: .integer)
        ], required: ["name", "muscleGroup", "type", "sets", "reps"])
    }

    nonisolated private var smartActionSchema: GeminiSchema {
        GeminiSchema(
            type: .object,
            properties: [
                "action": GeminiSchema(type: .string, description: "One of: swap, reduce_weight, increase_weight, add_finisher"),
                "exerciseName": GeminiSchema(type: .string, description: "Name of the target exercise in English"),
                "setsRemaining": GeminiSchema(type: .integer, description: "Number of sets to add or modify"),
                "weightValue": GeminiSchema(type: .number, description: "New recommended weight"),
                "reasoning": GeminiSchema(type: .string, description: "Short, motivational reasoning explaining the change.")
            ],
            required: ["action", "exerciseName", "setsRemaining", "weightValue", "reasoning"]
        )
    }

    nonisolated private var inWorkoutResponseSchema: GeminiSchema {
        GeminiSchema(
            type: .object,
            properties: [
                "explanation": GeminiSchema(type: .string, description: "Short motivational reasoning"),
                "actionType": GeminiSchema(type: .string, description: "One of: dropWeight, addSet, replaceExercise, skipExercise, reduceRemainingLoad, none"),
                "targetExerciseName": GeminiSchema(type: .string),
                "valuePercentage": GeminiSchema(type: .number),
                "valueReps": GeminiSchema(type: .integer),
                "valueWeightKg": GeminiSchema(type: .number),
                "replacementExerciseName": GeminiSchema(type: .string)
            ],
            required: ["explanation", "actionType"]
        )
    }

    nonisolated private var multiDayProgramSchema: GeminiSchema {
        let routineSchema = GeminiSchema(
            type: .object,
            properties: [
                "dayName": GeminiSchema(type: .string),
                "focus": GeminiSchema(type: .string),
                "exercises": GeminiSchema(type: .array, items: exerciseSchema)
            ],
            required: ["dayName", "focus", "exercises"]
        )
        return GeminiSchema(
            type: .object,
            properties: [
                "title": GeminiSchema(type: .string),
                "description": GeminiSchema(type: .string),
                "durationWeeks": GeminiSchema(type: .integer),
                "schedule": GeminiSchema(type: .array, items: routineSchema)
            ],
            required: ["title", "description", "durationWeeks", "schedule"]
        )
    }

    nonisolated private var chatResponseSchema: GeminiSchema {
        GeminiSchema(
            type: .object,
            properties: [
                "aiMessage": GeminiSchema(type: .string, description: "Your conversational response or answer to the user's question."),
                "hasWorkout": GeminiSchema(type: .boolean, description: "Set to true ONLY IF the user explicitly asked you to generate a workout routine/plan."),
                "workoutTitle": GeminiSchema(type: .string, description: "Title of the workout (only if hasWorkout is true)"),
                "exercises": GeminiSchema(type: .array, items: exerciseSchema, description: "The exercises (only if hasWorkout is true)")
            ],
            required: ["aiMessage", "hasWorkout"]
        )
    }

    nonisolated private var recoverySchema: GeminiSchema {
        GeminiSchema(
            type: .object,
            properties: [
                "recommendedHours": GeminiSchema(type: .number, description: "Recommended recovery time in hours (e.g., 24, 48, 72, 96).")
            ],
            required: ["recommendedHours"]
        )
    }

    nonisolated private var weeklyReviewSchema: GeminiSchema {
        GeminiSchema(
            type: .object,
            properties: [
                "weeklyScore": GeminiSchema(type: .integer, description: "Overall score from 0 to 100 based on performance and consistency."),
                "title": GeminiSchema(type: .string, description: "Short, punchy title (e.g. 'Unstoppable!', 'Slipping Up')."),
                "topHighlight": GeminiSchema(type: .string, description: "Short sentence about their best achievement this week."),
                "weakPointAlert": GeminiSchema(type: .string, description: "Short sentence about what they neglected or need to fix."),
                "coachAdvice": GeminiSchema(type: .string, description: "Main actionable advice for next week."),
                "coachMood": GeminiSchema(type: .string, description: "Must be exactly one of: 'fire' (great job), 'ice' (steady/cold logic), 'warning' (bad performance).")
            ],
            required: ["weeklyScore", "title", "topHighlight", "weakPointAlert", "coachAdvice", "coachMood"]
        )
    }

    // MARK: - Public API

    public func classifyIntent(userMessage: String) async throws -> Bool {
        let systemPrompt = "Analyze the user's message. Does the user explicitly ask to create, build, or generate a workout plan or routine? Reply ONLY with 'true' or 'false'."
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userMessage)])],
            generationConfig: .init(temperature: 0.1, responseMimeType: "text/plain", responseSchema: nil)
        )
        let response = try await networkClient.generateText(from: requestBody)
        return response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
    }

    public func generateChatTitle(for userMessage: String) async throws -> String {
        let isRussian = Locale.current.language.languageCode?.identifier == "ru"
        let systemPrompt = isRussian
            ? "Придумай очень краткое название (максимум 2-3 слова) для чата о фитнесе. Верни только текст без кавычек."
            : "Create a very short title (max 2-3 words) for a fitness chat. Return ONLY the text without quotes."
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userMessage)])],
            generationConfig: .init(temperature: 0.7, responseMimeType: "text/plain", responseSchema: nil)
        )
        return try await networkClient.generateText(from: requestBody).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func generatePerformanceReview(statsContext: String, language: String) async throws -> AIWeeklyReviewDTO {
        let isRussian = language == "Russian"
        let langInstruction = isRussian
            ? "ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ (но значения ключей JSON оставь английскими). Будь кратким и мотивирующим."
            : "REPLY STRICTLY IN ENGLISH. Be brief and motivational."
        let systemPrompt = """
        You are an elite data analyst and supportive AI strength coach.
        Analyze the user's weekly statistics.
        Calculate a weeklyScore (0-100).
        Assign a coachMood ('fire' for great week, 'ice' for average/consistent, 'warning' for skipped workouts or low volume).
        \(langInstruction)
        """
        let userStatsHeader = isRussian ? "Моя статистика:" : "My stats:"
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "\(userStatsHeader)\n\(statsContext)")])],
            generationConfig: .init(
                temperature: 0.4,
                responseMimeType: "application/json",
                responseSchema: weeklyReviewSchema
            )
        )
        let responseText = try await networkClient.generateText(from: requestBody)
        guard let jsonData = responseText.data(using: .utf8) else {
            throw AILogicError.noDataReturned
        }
        // DTO is MainActor-isolated — decode on main actor.
        return try await MainActor.run {
            try JSONDecoder().decode(AIWeeklyReviewDTO.self, from: jsonData)
        }
    }

    public func streamChatResponse(userRequest: String, userProfile: UserProfileContext) async throws -> AsyncThrowingStream<String, Error> {
        let langLine = userProfile.language == "Russian"
            ? "ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ."
            : ""
        let prompt = """
        You are an elite AI Strength Coach. Your tone is \(userProfile.aiCoachTone).
        Answer the user's fitness questions conversationally. DO NOT generate structured workout plans here.
        Weights must be in \(userProfile.weightUnit).
        \(langLine)
        """
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: prompt)]),
            contents: [.init(role: "user", parts: [.init(text: userRequest)])],
            generationConfig: .init(temperature: 0.7, responseMimeType: "text/plain", responseSchema: nil)
        )
        return try await networkClient.streamText(from: requestBody)
    }

    public func generateWorkoutPlan(userRequest: String, userProfile: UserProfileContext) async throws -> AICoachResponseDTO {
        // [5.1.3] Body weight stays on-device. The AI uses experience level + PRs only.
        let systemPrompt = await createSystemPrompt(profile: userProfile)
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "REQUEST: \"\(userRequest)\"")])],
            generationConfig: .init(
                temperature: 0.4,
                responseMimeType: "application/json",
                responseSchema: chatResponseSchema
            )
        )
        let responseText = try await networkClient.generateText(from: requestBody)
        guard let jsonData = responseText.data(using: .utf8) else {
            throw AILogicError.noDataReturned
        }
        let networkResponse = try JSONDecoder().decode(ChatNetworkResponse.self, from: jsonData)
        if networkResponse.hasWorkout, let exs = networkResponse.exercises, !exs.isEmpty {
            let workoutDTO = GeneratedWorkoutDTO(
                title: networkResponse.workoutTitle ?? "Custom Workout",
                aiMessage: networkResponse.aiMessage,
                exercises: exs
            )
            return AICoachResponseDTO(text: networkResponse.aiMessage, workout: workoutDTO)
        } else {
            return AICoachResponseDTO(text: networkResponse.aiMessage, workout: nil)
        }
    }

    public func processSmartAction(commandType: String,
                                   workoutContext: String,
                                   catalogContext: String,
                                   weightUnit: String,
                                   language: String) async throws -> SmartActionDTO {
        let isRussian = language == "Russian"
        let langInstruction = isRussian
            ? "ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ (но ключи JSON оставь на английском)."
            : "REPLY STRICTLY IN ENGLISH."
        let systemPrompt = """
        You are an elite AI-coach. Your task is to instantly adjust the current workout upon request.
        If switching from barbell to dumbbells — reduce weight by 15-20%. If "Too Heavy" - reduce by 10%.
        \(langInstruction)
        AVAILABLE EXERCISES FOR SWAP:
        \(catalogContext)
        """
        let userPrompt = "Current workout:\n\(workoutContext)\n\nUser command: \(commandType)"
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userPrompt)])],
            generationConfig: .init(temperature: 0.3, responseMimeType: "application/json", responseSchema: smartActionSchema)
        )
        let responseText = try await networkClient.generateText(from: requestBody)
        guard let jsonData = responseText.data(using: .utf8) else {
            throw AILogicError.noDataReturned
        }
        return try await MainActor.run {
            try JSONDecoder().decode(SmartActionDTO.self, from: jsonData)
        }
    }

    public func analyzeActiveWorkout(userMessage: String,
                                     workoutContext: String,
                                     catalogContext: String,
                                     tone: String,
                                     weightUnit: String) async throws -> InWorkoutResponseDTO {
        let isRussian = Locale.current.language.languageCode?.identifier == "ru"
        let langInstruction = isRussian
            ? "ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ. Названия упражнений оставляй на английском."
            : "REPLY STRICTLY IN ENGLISH."
        let systemPrompt = """
        You are an elite AI Strength Coach. \(langInstruction)
        All weights are in \(weightUnit).
        AVAILABLE EXERCISES FOR SWAP:
        \(catalogContext)
        """
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "CONTEXT:\n\(workoutContext)\nUSER: \"\(userMessage)\"")])],
            generationConfig: .init(temperature: 0.2, responseMimeType: "application/json", responseSchema: inWorkoutResponseSchema)
        )
        let responseText = try await networkClient.generateText(from: requestBody)
        guard let jsonData = responseText.data(using: .utf8) else {
            throw AILogicError.noDataReturned
        }
        return try await MainActor.run {
            try JSONDecoder().decode(InWorkoutResponseDTO.self, from: jsonData)
        }
    }

    public func generateMultiDayProgram(goal: String,
                                        level: String,
                                        days: Int,
                                        equipment: String,
                                        musclesToGrow: [String],
                                        musclesToExclude: [String],
                                        language: String,
                                        catalogContext: String) async throws -> GeneratedProgramDTO {
        let isRussian = language == "Russian"
        let langInstruction = isRussian
            ? "ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ (ключи JSON оставь на английском)."
            : "REPLY STRICTLY IN ENGLISH."
        let growList = musclesToGrow.isEmpty ? "None specified" : musclesToGrow.joined(separator: ", ")
        let excludeList = musclesToExclude.isEmpty ? "None specified" : musclesToExclude.joined(separator: ", ")
        let systemPrompt = """
        You are an elite AI Strength & Conditioning Architect. Design a premium multi-day workout program.
        \(langInstruction)
        RULES:
        Create EXACTLY \(days) workout days.
        Goal: \(goal). Experience Level: \(level). Available Equipment: \(equipment).
        FOCUS HEAVILY on growing: \(growList).
        EXCLUDE exercises targeting: \(excludeList).
        MUST use exercises EXCLUSIVELY from this approved list: \(catalogContext). Do NOT invent exercises.
        """
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "Generate my \(days)-day program.")])],
            generationConfig: .init(temperature: 0.4, responseMimeType: "application/json", responseSchema: multiDayProgramSchema)
        )
        let responseText = try await networkClient.generateText(from: requestBody)
        guard let jsonData = responseText.data(using: .utf8) else {
            throw AILogicError.noDataReturned
        }
        return try await MainActor.run {
            try JSONDecoder().decode(GeneratedProgramDTO.self, from: jsonData)
        }
    }

    public func calculateOptimalRecoveryTime(workoutContext: String) async throws -> Double {
        let systemPrompt = """
        You are an elite sports scientist. Analyze the workout summary provided by the user.
        Based on the total volume, number of sets, and average effort (RPE/Intensity), calculate the optimal muscle recovery time in hours.
        Return ONLY a JSON object containing 'recommendedHours'.
        """
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "WORKOUT SUMMARY:\n\(workoutContext)")])],
            generationConfig: .init(temperature: 0.1, responseMimeType: "application/json", responseSchema: recoverySchema)
        )
        let responseText = try await networkClient.generateText(from: requestBody)
        guard let jsonData = responseText.data(using: .utf8) else {
            throw AILogicError.noDataReturned
        }
        let response = try JSONDecoder().decode(RecoveryResponseDTO.self, from: jsonData)
        return min(max(response.recommendedHours, 12.0), 120.0)
    }

    // MARK: - Private prompt builder

    private func createSystemPrompt(profile: UserProfileContext) async -> String {
        let persona = await RemoteConfigManager.shared.getPersona(id: profile.aiCoachTone)
        let customInstruction = persona?.systemInstruction ?? "You are an elite AI Strength Coach."

        // [5.1.3] Privacy: do NOT include the user's body weight in the prompt.
        var prompt = """
        \(customInstruction)
        You can chat, answer fitness questions, OR generate workout plans.
        USER PROFILE (non-sensitive):
        Experience level: \(profile.experienceLevel)
        Workouts this week: \(profile.workoutsThisWeek)
        Current streak: \(profile.currentStreak) days
        RULES FOR JSON RESPONSE:
        "aiMessage": ALWAYS provide your conversational response here.
        "hasWorkout": Set to true ONLY if the user explicitly asks for a workout plan or routine. If they just say "Hello" or ask a general question, set it to false.
        "workoutTitle" and "exercises": ONLY fill these if hasWorkout is true.
        Weights must be in \(profile.weightUnit).
        When recommending loads, use generic strength-training guidelines based on the user's experience level. Do NOT ask the user for their body weight.
        """

        if profile.language == "Russian" {
            prompt += "\nОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ (кроме названий упражнений)."
        }
        if !profile.availableExercises.isEmpty {
            prompt += "\nAVAILABLE EXERCISES FOR WORKOUTS:\n\(profile.availableExercises.joined(separator: ", "))"
        }
        if !profile.recentPRs.isEmpty {
            let prSummary = profile.recentPRs
                .map { "\($0.key): \($0.value) kg" }
                .joined(separator: ", ")
            prompt += "\nRECENT PRs (use to calibrate intensity):\n\(prSummary)"
        }
        if !profile.fatiguedMuscles.isEmpty {
            prompt += "\nFATIGUED MUSCLE GROUPS (avoid heavy loading): \(profile.fatiguedMuscles.joined(separator: ", "))"
        }
        return prompt
    }
}

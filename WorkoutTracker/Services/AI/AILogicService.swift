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
    case aiConsentRequired
    case invalidData
    case friendlyError
    case apiError(statusCode: Int, message: String)
    case badRequest(reason: String)
    case decodingFailed(Error)
    case rateLimited(retryAfter: TimeInterval?)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:        return "The URL provided is invalid."
        case .invalidResponse:   return "Received an invalid response from the server."
        case .aiConsentRequired:
            return NSLocalizedString(
                "AI features require your consent before your messages can be sent for processing.",
                comment: "Shown when the user hasn't consented to AI processing yet"
            )
        case .noDataReturned:    return "No data was returned from the server."
        case .invalidData:       return "The AI response was malformed."
        case .rateLimited:
            return "The AI is currently under high load. Please wait a moment while we reconnect."
        case .friendlyError:     return "Sorry, I got a little confused. Could you rephrase that?"
        case .badRequest(let reason):
            return "Your request couldn't be processed. \(reason)"
        case .apiError(let code, _):
            if code == 400 {
                return "The request was invalid or too large. Please try asking a shorter question."
            } else if code >= 500 {
                return String(localized: "The AI coach service is temporarily unavailable. Please try again later.")
            }
            return String(localized: "The AI service couldn't complete your request. Please try again.")
        case .decodingFailed:
            return String(localized: "We couldn't read the AI response. Please try again.")
        }
    }
}

extension Error {
    /// Human-readable message for AI UI (chat, builders, weekly review).
    var userFacingAIMessage: String {
        if let ai = self as? AILogicError, let description = ai.errorDescription {
            return description
        }
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                return String(localized: "You're offline. Check your connection and try again.")
            case .timedOut, .cannotConnectToHost, .dnsLookupFailed:
                return String(localized: "The request timed out. Check your connection and try again.")
            default:
                break
            }
        }
        let ns = self as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed:
                return String(localized: "You're offline. Check your connection and try again.")
            case NSURLErrorTimedOut, NSURLErrorCannotConnectToHost:
                return String(localized: "The request timed out. Check your connection and try again.")
            default:
                return String(localized: "Couldn't reach the AI service. Please try again.")
            }
        }
        return String(localized: "Something went wrong. Please try again.")
    }
}

private struct ChatNetworkResponse: Codable, Sendable {
    let aiMessage: String
    let hasWorkout: Bool
    let workoutTitle: String?
    let exercises: [GeneratedExerciseDTO]?
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

    nonisolated private var builderWorkoutSchema: GeminiSchema {
        GeminiSchema(
            type: .object,
            properties: [
                "aiMessage": GeminiSchema(type: .string, description: "Short motivating greeting for the user."),
                "workoutTitle": GeminiSchema(type: .string, description: "Title of the workout."),
                "exercises": GeminiSchema(type: .array, items: exerciseSchema, description: "Exactly 4 or 5 exercises for the requested muscle group.")
            ],
            required: ["aiMessage", "workoutTitle", "exercises"]
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

    /// Prefer `AIIntentClassifier` on-device. Kept for callers that still await a Bool.
    public func classifyIntent(userMessage: String) async throws -> Bool {
        AIIntentClassifier.wantsWorkoutPlan(userMessage)
    }

    /// Decode JSON model output after stripping markdown/prose wrappers.
    private func decodeJSON<T: Decodable>(_ type: T.Type, from raw: String) throws -> T {
        let cleaned = AIResponseParsing.extractJSONObject(from: raw)
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw AILogicError.noDataReturned
        }
        do {
            return try JSONDecoder().decode(type, from: jsonData)
        } catch {
            throw AILogicError.decodingFailed(error)
        }
    }

    public func generateChatTitle(for userMessage: String) async throws -> String {
        let languageId = Locale.current.language.languageCode?.identifier ?? "en"
        let language = Locale(identifier: "en").localizedString(forIdentifier: languageId) ?? "English"
        let langInstruction = language.lowercased() == "english" ? "ENGLISH" : language.uppercased()
        let systemPrompt = "Create a very short title (max 2-3 words) for a fitness chat. Return ONLY the text without quotes. REPLY STRICTLY IN \(langInstruction)."
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userMessage)])],
            generationConfig: .init(temperature: 0.7, responseMimeType: "text/plain", responseSchema: nil)
        )
        return try await networkClient.generateText(from: requestBody).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func generatePerformanceReview(statsContext: String, language: String) async throws -> AIWeeklyReviewDTO {
        let langInstruction = language.lowercased() == "english"
            ? "REPLY STRICTLY IN ENGLISH. Be brief and motivational."
            : "REPLY STRICTLY IN \(language.uppercased()) (but keep any JSON keys in English). Be brief and motivational."
        let systemPrompt = """
        You are an elite data analyst and supportive AI strength coach.
        Analyze the user's weekly statistics and return ONE JSON object only (no markdown).
        Fields:
        - weeklyScore: integer 0-100
        - title: short punchy title
        - topHighlight: one sentence best win
        - weakPointAlert: one sentence gap
        - coachAdvice: one actionable tip for next week
        - coachMood: EXACTLY one of: fire | ice | warning
        \(langInstruction)
        """
        let userStatsHeader = "My stats:"
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
        let review = try decodeJSON(AIWeeklyReviewDTO.self, from: responseText)
        let score = min(max(review.weeklyScore, 0), 100)
        // Free models sometimes answer on a 0–10 scale; scale up when mood says it was strong.
        let normalizedScore: Int = {
            if score <= 10, ["fire", "ice"].contains(review.coachMood.lowercased()) {
                return score * 10
            }
            return score
        }()
        return AIWeeklyReviewDTO(
            weeklyScore: normalizedScore,
            title: review.title,
            topHighlight: review.topHighlight,
            weakPointAlert: review.weakPointAlert,
            coachAdvice: review.coachAdvice,
            coachMood: review.coachMood
        )
    }

    public func streamChatResponse(userRequest: String, userProfile: UserProfileContext) async throws -> AsyncThrowingStream<String, Error> {
        let langLine = userProfile.language.lowercased() == "english"
            ? "REPLY STRICTLY IN ENGLISH."
            : "REPLY STRICTLY IN \(userProfile.language.uppercased())."
        let prompt = """
        You are an elite AI Strength Coach. Your tone is \(userProfile.aiCoachTone).
        Answer the user's fitness questions conversationally in plain text (no JSON, no markdown code fences).
        DO NOT generate structured workout plans or exercise tables here — give coaching advice only.
        Weights must be in \(userProfile.weightUnit).
        Never ask for body weight. Use experience level and any PRs provided in the user message.
        \(langLine)
        """
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: prompt)]),
            contents: [.init(role: "user", parts: [.init(text: userRequest)])],
            generationConfig: .init(temperature: 0.7, responseMimeType: "text/plain", responseSchema: nil)
        )
        return try await networkClient.streamText(from: requestBody)
    }

    public func generateBuilderRoutine(muscleGroup: String, difficulty: String, availableExercises: [String], weightUnit: String, language: String, userName: String, fatiguedMuscles: [String] = []) async throws -> AICoachResponseDTO {
        let langLine = language.lowercased() == "english"
            ? "REPLY STRICTLY IN ENGLISH."
            : "REPLY STRICTLY IN \(language.uppercased()) (but keep exercise names in English)."
        let exerciseList = availableExercises.isEmpty
            ? "Bench Press, Squat, Deadlift, Pull-ups, Dumbbell Curls, Shoulder Press, Lunges, Plank"
            : availableExercises.joined(separator: ", ")
        var systemPrompt = """
        You are an elite AI Strength Coach. Return ONE JSON object only (no markdown).
        \(langLine)
        Weights must be in \(weightUnit). recommendedWeightKg is always numeric kilograms even if display unit differs.
        RULES:
        - exercises: EXACTLY 4 or 5 items. MANDATORY.
        - Choose exercises ONLY from this approved list (match names exactly): \(exerciseList)
        - Do NOT invent exercise names.
        - User experience level: \(difficulty). Scale sets/reps/load accordingly.
        - workoutTitle: "Protocol: \(muscleGroup)"
        - aiMessage: short energetic greeting addressing \(userName.isEmpty ? "Athlete" : userName)
        - Each exercise needs: name, muscleGroup, type, sets, reps (integers). Optional: recommendedWeightKg, restSeconds.
        """
        if !fatiguedMuscles.isEmpty {
            systemPrompt += "\n- FATIGUED MUSCLES (avoid heavy loading on these): \(fatiguedMuscles.joined(separator: ", "))"
        }
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "Generate a \(muscleGroup) workout at \(difficulty) level.")])],
            generationConfig: .init(
                temperature: 0.4,
                responseMimeType: "application/json",
                responseSchema: builderWorkoutSchema
            )
        )
        let responseText = try await networkClient.generateText(from: requestBody)

        struct BuilderResponse: Codable {
            let aiMessage: String
            let workoutTitle: String?
            let exercises: [GeneratedExerciseDTO]?
        }

        let parsed = try decodeJSON(BuilderResponse.self, from: responseText)
        guard let exs = parsed.exercises, !exs.isEmpty else {
            throw AILogicError.invalidData
        }
        let workoutDTO = GeneratedWorkoutDTO(
            title: parsed.workoutTitle ?? "Protocol: \(muscleGroup)",
            aiMessage: parsed.aiMessage,
            exercises: exs
        )
        return AICoachResponseDTO(text: parsed.aiMessage, workout: workoutDTO)
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
        let networkResponse = try decodeJSON(ChatNetworkResponse.self, from: responseText)
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
        let langInstruction = language.lowercased() == "english"
            ? "REPLY STRICTLY IN ENGLISH."
            : "REPLY STRICTLY IN \(language.uppercased()) (but keep any JSON keys in English)."
        let systemPrompt = """
        You are an elite AI coach. Return ONE JSON object only (no markdown) to adjust the live workout.
        action must be EXACTLY one of: swap | reduce_weight | increase_weight | add_finisher
        If switching barbell→dumbbells: reduce weight 15-20%. If "Too Heavy": reduce ~10%. If "Too Easy": increase ~5-10%.
        exerciseName must match an exercise from the current workout (English name).
        setsRemaining and weightValue are required numbers (use 0 if unused).
        reasoning: one short motivational sentence.
        \(langInstruction)
        AVAILABLE EXERCISES FOR SWAP (use exact names only):
        \(catalogContext)
        """
        let userPrompt = "Current workout:\n\(workoutContext)\n\nUser command: \(commandType)"
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: userPrompt)])],
            generationConfig: .init(temperature: 0.3, responseMimeType: "application/json", responseSchema: smartActionSchema)
        )
        let responseText = try await networkClient.generateText(from: requestBody)
        return try decodeJSON(SmartActionDTO.self, from: responseText)
    }

    public func analyzeActiveWorkout(userMessage: String,
                                     workoutContext: String,
                                     catalogContext: String,
                                     tone: String,
                                     weightUnit: String) async throws -> InWorkoutResponseDTO {
        let languageId = Locale.current.language.languageCode?.identifier ?? "en"
        let language = Locale(identifier: "en").localizedString(forIdentifier: languageId) ?? "English"
        let langInstruction = language.lowercased() == "english"
            ? "REPLY STRICTLY IN ENGLISH."
            : "REPLY STRICTLY IN \(language.uppercased()). Leave exercise names in English."
        let systemPrompt = """
        You are an elite AI Strength Coach. Return ONE JSON object only (no markdown).
        \(langInstruction)
        All weights are in \(weightUnit).
        actionType must be EXACTLY one of: dropWeight | addSet | replaceExercise | skipExercise | reduceRemainingLoad | none
        Prefer "none" if the user only asked a question with no workout change.
        When replacing, replacementExerciseName MUST be from the approved list (exact name).
        AVAILABLE EXERCISES FOR SWAP:
        \(catalogContext)
        """
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "CONTEXT:\n\(workoutContext)\nUSER: \"\(userMessage)\"")])],
            generationConfig: .init(temperature: 0.2, responseMimeType: "application/json", responseSchema: inWorkoutResponseSchema)
        )
        let responseText = try await networkClient.generateText(from: requestBody)
        return try decodeJSON(InWorkoutResponseDTO.self, from: responseText)
    }

    public func generateMultiDayProgram(goal: String,
                                        level: String,
                                        days: Int,
                                        equipment: String,
                                        musclesToGrow: [String],
                                        musclesToExclude: [String],
                                        language: String,
                                        catalogContext: String) async throws -> GeneratedProgramDTO {
        let langInstruction = language.lowercased() == "english"
            ? "REPLY STRICTLY IN ENGLISH."
            : "REPLY STRICTLY IN \(language.uppercased()) (but keep any JSON keys in English)."
        let growList = musclesToGrow.isEmpty ? "None specified" : musclesToGrow.joined(separator: ", ")
        let excludeList = musclesToExclude.isEmpty ? "None specified" : musclesToExclude.joined(separator: ", ")
        let systemPrompt = """
        You are an elite AI Strength & Conditioning Architect. Return ONE JSON object only (no markdown).
        \(langInstruction)
        RULES:
        - schedule must contain EXACTLY \(days) days (dayName, focus, exercises[]).
        - Goal: \(goal). Level: \(level). Equipment: \(equipment).
        - Focus growth on: \(growList). Exclude: \(excludeList).
        - EVERY exercise name MUST be copied exactly from this approved list (comma-separated). Do NOT invent names:
        \(catalogContext)
        - Keep each day to 4–6 exercises. Prefer compound lifts first.
        - durationWeeks: integer 4–12.
        """
        let requestBody = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "Generate my \(days)-day program.")])],
            generationConfig: .init(temperature: 0.4, responseMimeType: "application/json", responseSchema: multiDayProgramSchema)
        )
        let responseText = try await networkClient.generateText(from: requestBody)
        return try decodeJSON(GeneratedProgramDTO.self, from: responseText)
    }

    // MARK: - Private prompt builder

    private func createSystemPrompt(profile: UserProfileContext) async -> String {
        let persona = await RemoteConfigManager.shared.getPersona(id: profile.aiCoachTone)
        let customInstruction = persona?.systemInstruction ?? "You are an elite AI Strength Coach."

        // [5.1.3] Privacy: do NOT include the user's body weight in the prompt.
        var prompt = """
        \(customInstruction)
        Return ONE JSON object only (no markdown fences).
        You can chat, answer fitness questions, OR generate workout plans.
        USER PROFILE (non-sensitive):
        Name: \(profile.userName.isEmpty ? "Athlete" : profile.userName)
        Experience level: \(profile.experienceLevel)
        Workouts this week: \(profile.workoutsThisWeek)
        Current streak: \(profile.currentStreak) days
        RULES FOR JSON RESPONSE:
        - aiMessage: ALWAYS fill (conversational). Occasionally use their name.
        - hasWorkout: true ONLY if they explicitly ask for a workout/routine/program.
        - workoutTitle + exercises: only when hasWorkout is true; otherwise omit or use empty exercises.
        - When hasWorkout is true: 4–6 exercises, names ONLY from AVAILABLE EXERCISES (exact match). Do not invent names.
        - Each exercise: name, muscleGroup, type, sets, reps (ints). Optional recommendedWeightKg, restSeconds.
        Weights must be in \(profile.weightUnit).
        Use experience + PRs to calibrate load. Do NOT ask for body weight.
        """

        if profile.language.lowercased() != "english" {
            prompt += "\nREPLY STRICTLY IN \(profile.language.uppercased()) (except for exercise names)."
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

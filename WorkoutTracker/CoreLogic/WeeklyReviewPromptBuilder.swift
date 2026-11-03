import Foundation

/// Weekly muscle review must send the focus the user picked and the profile we actually have.
enum WeeklyReviewPromptBuilder {
    static func userRequest(focus: String, statsBlock: String) -> String {
        """
        You are a professional AI trainer.
        The user is looking at the muscle load distribution analytics.
        Their emphasis is now: "\(focus)".
        Analyze the provided data and write a short, motivating, and direct conclusion/advice in the user's language (2-3 sentences maximum).
        Point out obvious imbalances or praise focus. Do not use Markdown formatting (no asterisks or bold).

        \(statsBlock)
        """
    }

    static func profile(
        userName: String,
        weightKg: Double,
        weightUnit: String,
        tone: String,
        workoutsThisWeek: Int,
        currentStreak: Int,
        language: String
    ) -> UserProfileContext {
        UserProfileContext(
            userName: userName.isEmpty ? "Athlete" : userName,
            weightKg: weightKg,
            experienceLevel: "Not specified",
            favoriteMuscles: [],
            recentPRs: [:],
            language: language,
            workoutsThisWeek: workoutsThisWeek,
            currentStreak: currentStreak,
            fatiguedMuscles: [],
            availableExercises: [],
            aiCoachTone: tone,
            weightUnit: weightUnit
        )
    }
}

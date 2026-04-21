

import Foundation

struct StreakCalculator: Sendable {
    static func calculate(from workoutDates: [Date], maxRestDays: Int) -> Int {
        guard !workoutDates.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedUniqueDates = Array(Set(workoutDates.map { calendar.startOfDay(for: $0) })).sorted(by: >)

        guard let mostRecent = sortedUniqueDates.first else { return 0 }
        let daysSinceLastWorkout = calendar.dateComponents([.day], from: mostRecent, to: calendar.startOfDay(for: Date())).day ?? 0

        if daysSinceLastWorkout > maxRestDays { return 0 }

        var currentStreak = 1
        var lastDate = mostRecent

        guard sortedUniqueDates.count > 1 else { return 1 }

        for date in sortedUniqueDates.dropFirst() {
            let daysBetween = calendar.dateComponents([.day], from: date, to: lastDate).day ?? 0
            if daysBetween <= maxRestDays + 1 {
                currentStreak += 1
                lastDate = date
            } else {
                break
            }
        }
        return currentStreak
    }
}

struct WeakPointCalculator: Sendable {

    struct MuscleRawData {
        let slug: String
        let frequency: Int
        let totalVolume: Double
    }

    static func calculate(from data: [MuscleRawData]) -> [WeakPoint] {
        guard !data.isEmpty else { return [] }

        let count = Double(data.count)
        let avgFreq = data.map { Double($0.frequency) }.reduce(0, +) / count
        let avgVol = data.map { $0.totalVolume }.reduce(0, +) / count

        let names: [String: String] = [
            "chest": String(localized: "Chest"), "upper-back": String(localized: "Back"),
            "lower-back": String(localized: "Lower Back"), "deltoids": String(localized: "Shoulders"),
            "biceps": String(localized: "Biceps"), "triceps": String(localized: "Triceps"),
            "abs": String(localized: "Abs"), "gluteal": String(localized: "Glutes"),
            "hamstring": String(localized: "Hamstrings"), "quadriceps": String(localized: "Legs"),
            "calves": String(localized: "Calves")
        ]

        var weakPoints: [WeakPoint] = []

        for item in data {
            let freq = item.frequency
            let vol = item.totalVolume / Double(max(freq, 1))

            if Double(freq) < avgFreq * 0.7 || vol < avgVol * 0.7 {
                let rec: String
                if freq == 0 {
                    rec = String(localized: "Start training this muscle group")
                } else if Double(freq) < avgFreq * 0.5 {
                    rec = String(localized: "Increase training frequency")
                } else {
                    rec = String(localized: "Increase training volume")
                }

                weakPoints.append(WeakPoint(
                    id: UUID(),
                    muscleGroup: names[item.slug] ?? item.slug.capitalized,
                    frequency: freq,
                    averageVolume: vol,
                    recommendation: rec
                ))
            }
        }

        return weakPoints.sorted { $0.frequency < $1.frequency }
    }
}

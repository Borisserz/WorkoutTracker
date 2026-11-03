import Foundation
import Testing
import SwiftData
@testable import WorkoutTracker

@Suite("Honesty windows")
struct HonestyWindowTests {

    @Test("Best sessions rank by volume across the whole history, not the newest page")
    func bestSessionsIgnoreRecencyPage() throws {
        let schema = Schema([
            Workout.self, WorkoutPreset.self, ExerciseNote.self, UserStats.self,
            ExerciseStat.self, MuscleStat.self, WeightEntry.self, MuscleColorPreference.self,
            AIChatSession.self, BodyMeasurement.self, ExerciseDictionaryItem.self, UserGoal.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let old = Workout(title: "Old PR", date: Date().addingTimeInterval(-86400 * 400))
        old.endTime = old.date.addingTimeInterval(3600)
        old.totalStrengthVolume = 50_000
        context.insert(old)

        for index in 0..<60 {
            let recent = Workout(title: "Recent \(index)", date: Date().addingTimeInterval(Double(-index) * 3600))
            recent.endTime = recent.date.addingTimeInterval(1800)
            recent.totalStrengthVolume = 100
            context.insert(recent)
        }
        try context.save()

        let fetched = try context.fetch(HistoryBestSessionQuery.descriptor())
        #expect(fetched.first?.title == "Old PR")
        #expect(fetched.count == HistoryBestSessionQuery.limit)
    }

    @Test("All-time best month is the busiest month, even when it is older than the dashboard window")
    func bestMonthUsesFullHistory() {
        let calendar = Calendar(identifier: .gregorian)
        let oldDate = DateComponents(calendar: calendar, year: 2020, month: 1, day: 10).date!
        let recentDate = DateComponents(calendar: calendar, year: 2026, month: 10, day: 2).date!

        var samples: [FinishedSessionSample] = []
        for day in 0..<8 {
            samples.append(FinishedSessionSample(
                date: calendar.date(byAdding: .day, value: day, to: oldDate)!,
                volumeKg: 1_000,
                reps: 40,
                durationMinutes: 50,
                distanceMeters: 0
            ))
        }
        samples.append(FinishedSessionSample(
            date: recentDate,
            volumeKg: 9_000,
            reps: 10,
            durationMinutes: 40,
            distanceMeters: 0
        ))

        let best = AllTimeBestMonth.rank(samples: samples, calendar: calendar)
        #expect(best.workoutCount == 8)
        #expect(best.totalVolume == 8_000)
    }

    @Test("Explore uses bundled samples only when the server catalog is empty")
    @MainActor
    func exploreFallsBackWhenRemoteEmpty() {
        let remote = MockProgramCatalog.shared.featuredPrograms
        let one = Array(remote.prefix(1))
        #expect(ExploreCatalogSource.programs(remote: [], offline: remote).count == remote.count)
        #expect(ExploreCatalogSource.programs(remote: one, offline: remote).count == 1)
        #expect(ExploreCatalogSource.isOffline(remoteCount: 0))
        #expect(!ExploreCatalogSource.isOffline(remoteCount: 3))
    }

    @Test("AI proxy URL accepts an https override and keeps the baked default otherwise")
    func proxyURLResolution() {
        let fallback = AIProxyEndpoint.fallbackURL
        #expect(AIProxyEndpoint.resolve(configured: nil) == fallback)
        #expect(AIProxyEndpoint.resolve(configured: "  ") == fallback)
        #expect(AIProxyEndpoint.resolve(configured: "http://evil.example") == fallback)
        let override = URL(string: "https://proxy.example/ai")!
        #expect(AIProxyEndpoint.resolve(configured: " https://proxy.example/ai ") == override)
    }
}

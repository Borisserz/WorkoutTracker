import Foundation
import SwiftData

/// Launch-argument harness for Maestro / UI tests and ASO screenshot capture.
/// Pass `-UITestMode` so the app skips onboarding and system permission prompts.
/// Pass `-ASODemoSeed` and `-ASORoute <route>` in Debug/Simulator to populate realistic athlete data.
enum UITestLaunchConfiguration {
    static var isUITestMode: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-UITestMode") || args.contains("UITestMode") || isASODemoSeed { return true }
        // Maestro may pass `-UITestMode true` as adjacent argv pairs.
        if let idx = args.firstIndex(of: "-UITestMode"), args.index(after: idx) < args.endIndex {
            return args[args.index(after: idx)].lowercased() != "false"
        }
        if ProcessInfo.processInfo.environment["UITEST_MODE"] == "1" { return true }
        // Unit tests: skip Health / TCC sheets that can hang xcodebuild test runners.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return true }
        return false
    }

    static var isASODemoSeed: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-ASODemoSeed") || ProcessInfo.processInfo.environment["ASO_DEMO_SEED"] == "1"
    }

    static var asoRoute: String? {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-ASORoute"), args.index(after: idx) < args.endIndex {
            return args[args.index(after: idx)]
        }
        return ProcessInfo.processInfo.environment["ASO_ROUTE"]
    }

    /// Call as early as possible (AppDelegate) before SwiftUI `@AppStorage` reads.
    static func applyIfNeeded() {
        guard isUITestMode else { return }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasCompletedGodModeOnboarding_v1")
        defaults.set(true, forKey: "hasSeenFeatureDiscovery")
        defaults.set(true, forKey: "hasSeenFoodTrackerPromo")
        defaults.set(true, forKey: SisterAppsPromoFlags.seenKey)
        defaults.set(true, forKey: "hasSeenCommitmentSheet")
        defaults.set(true, forKey: "hasSeenAICoachTooltip")
        // Skip AI consent sheet so Hub chrome flows can open chat/tools.
        defaults.set(true, forKey: Constants.UserDefaultsKeys.hasConsentedToAI.rawValue)
        // Avoid guest sign-up sheet after first finished workout in Maestro.
        defaults.set(true, forKey: "hasSeenGuestSignUpPrompt")
        // Dark-only lock already enforced by AppearanceMode; keep explicit for suites.
        defaults.set(AppearanceMode.lockedRawValue, forKey: Constants.UserDefaultsKeys.appearanceMode.rawValue)

        if isASODemoSeed {
            defaults.set("Alex", forKey: Constants.UserDefaultsKeys.userName.rawValue)
            defaults.set("male", forKey: "userGender")
            defaults.set(92.0, forKey: "cnsScore")
            defaults.set(7.8, forKey: "sleepHours")
            defaults.set(true, forKey: "hasSleepData")
            defaults.set(79.4, forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
            HydrationLog.write(2.4)
        }
    }

    @MainActor
    static func seedASODemoDataIfNeeded(
        container: ModelContainer,
        di: DIContainer,
        dashboardViewModel: DashboardViewModel?,
        restTimerManager: RestTimerManager?
    ) {
        guard isASODemoSeed else { return }
        let ctx = container.mainContext

        if let existingWorkouts = try? ctx.fetch(FetchDescriptor<Workout>()) {
            for w in existingWorkouts { ctx.delete(w) }
        }
        if let existingPresets = try? ctx.fetch(FetchDescriptor<WorkoutPreset>()) {
            for p in existingPresets where !p.isSystem { ctx.delete(p) }
        }
        if let existingWeights = try? ctx.fetch(FetchDescriptor<WeightEntry>()) {
            for we in existingWeights { ctx.delete(we) }
        }
        if let existingGoals = try? ctx.fetch(FetchDescriptor<UserGoal>()) {
            for g in existingGoals { ctx.delete(g) }
        }

        let now = Date()
        let cal = Calendar.current

        func makeExercise(
            _ name: String,
            muscle: String,
            sets: [(Double, Int, Bool)],
            effort: Int = 8,
            rest: Int = 90
        ) -> Exercise {
            let workoutSets = sets.enumerated().map { idx, item in
                WorkoutSet(index: idx + 1, weight: item.0, reps: item.1, isCompleted: item.2, type: .normal)
            }
            let ex = Exercise(
                name: name,
                muscleGroup: muscle,
                type: .strength,
                effort: effort,
                restSeconds: rest,
                setsList: workoutSets,
                isCompleted: sets.allSatisfy { $0.2 }
            )
            let vol = workoutSets.reduce(0.0) { $0 + ((($1.weight ?? 0) * Double($1.reps ?? 0)) * ($1.isCompleted ? 1 : 0)) }
            let maxW = workoutSets.compactMap { $0.isCompleted ? $0.weight : nil }.max() ?? 0
            ex.cachedVolume = vol
            ex.cachedMaxWeight = maxW
            return ex
        }

        // 1. Seed Custom Workout Templates (My Templates)
        let pushPreset = WorkoutPreset(
            name: "Push — Chest & Delts",
            icon: "dumbbell.fill",
            isSystem: false,
            createdAt: now.addingTimeInterval(-86400 * 14),
            exercises: [
                makeExercise("Barbell Bench Press", muscle: "Chest", sets: [(90, 8, false), (95, 8, false), (100, 6, false)]),
                makeExercise("Incline Dumbbell Press", muscle: "Chest", sets: [(36, 10, false), (38, 8, false), (38, 8, false)]),
                makeExercise("Seated Dumbbell Shoulder Press", muscle: "Shoulders", sets: [(30, 10, false), (32, 8, false), (32, 8, false)]),
                makeExercise("Cable Lateral Raise", muscle: "Shoulders", sets: [(14, 15, false), (16, 12, false), (16, 12, false)]),
                makeExercise("Triceps Rope Pushdown", muscle: "Arms", sets: [(32, 12, false), (36, 12, false), (36, 10, false)])
            ]
        )

        let pullPreset = WorkoutPreset(
            name: "Pull — V-Taper Back",
            icon: "figure.strengthtraining.traditional",
            isSystem: false,
            createdAt: now.addingTimeInterval(-86400 * 12),
            exercises: [
                makeExercise("Weighted Pull-Up", muscle: "Back", sets: [(15, 8, false), (20, 6, false), (20, 6, false)]),
                makeExercise("Barbell Bent-Over Row", muscle: "Back", sets: [(85, 8, false), (90, 8, false), (95, 6, false)]),
                makeExercise("Wide-Grip Lat Pulldown", muscle: "Back", sets: [(75, 10, false), (80, 10, false), (82.5, 8, false)]),
                makeExercise("Seated Cable Row", muscle: "Back", sets: [(75, 10, false), (80, 10, false), (80, 10, false)]),
                makeExercise("Incline Dumbbell Curl", muscle: "Arms", sets: [(18, 12, false), (20, 10, false), (20, 10, false)])
            ]
        )

        let legsPreset = WorkoutPreset(
            name: "Legs — Quad & Glute Focus",
            icon: "bolt.fill",
            isSystem: false,
            createdAt: now.addingTimeInterval(-86400 * 10),
            exercises: [
                makeExercise("Barbell Back Squat", muscle: "Legs", sets: [(125, 8, false), (135, 6, false), (142.5, 5, false)]),
                makeExercise("Romanian Deadlift", muscle: "Legs", sets: [(115, 8, false), (125, 8, false), (130, 6, false)]),
                makeExercise("Leg Press", muscle: "Legs", sets: [(220, 10, false), (240, 10, false), (260, 8, false)]),
                makeExercise("Bulgarian Split Squat", muscle: "Legs", sets: [(28, 10, false), (30, 10, false), (30, 8, false)]),
                makeExercise("Standing Calf Raise", muscle: "Legs", sets: [(90, 15, false), (100, 15, false), (100, 12, false)])
            ]
        )

        let upperPreset = WorkoutPreset(
            name: "Upper Body Power",
            icon: "flame.fill",
            isSystem: false,
            createdAt: now.addingTimeInterval(-86400 * 8),
            exercises: [
                makeExercise("Barbell Bench Press", muscle: "Chest", sets: [(95, 5, false), (100, 5, false), (105, 4, false)]),
                makeExercise("Pendlay Row", muscle: "Back", sets: [(85, 6, false), (90, 6, false), (92.5, 5, false)]),
                makeExercise("Overhead Barbell Press", muscle: "Shoulders", sets: [(60, 6, false), (65, 5, false), (67.5, 5, false)]),
                makeExercise("Weighted Dip", muscle: "Arms", sets: [(20, 8, false), (25, 8, false), (25, 6, false)])
            ]
        )

        for preset in [pushPreset, pullPreset, legsPreset, upperPreset] {
            ctx.insert(preset)
        }

        // 2. Seed Completed Workouts (realistic progression + recovery balance)
        func insertCompletedWorkout(
            title: String,
            hoursAgo: Double,
            durationMin: Int,
            icon: String,
            isFavorite: Bool = false,
            exercises: [Exercise]
        ) {
            let start = now.addingTimeInterval(-hoursAgo * 3600)
            let end = start.addingTimeInterval(Double(durationMin * 60))
            let w = Workout(
                title: title,
                date: start,
                endTime: end,
                icon: icon,
                exercises: exercises,
                isFavorite: isFavorite
            )
            w.durationSeconds = durationMin * 60
            w.effortPercentage = 84
            w.totalStrengthVolume = exercises.reduce(0.0) { $0 + $1.exerciseVolume }
            w.totalReps = exercises.reduce(0) { acc, ex in
                acc + ex.setsList.reduce(0) { $0 + ($1.isCompleted ? ($1.reps ?? 0) : 0) }
            }
            ctx.insert(w)
        }

        // Recent session 16 hours ago: Pull & Back (so Back shows ~66% amber recovery, while Chest & Legs are 90%+ fresh!)
        insertCompletedWorkout(
            title: "Pull — V-Taper Back",
            hoursAgo: 18,
            durationMin: 56,
            icon: "figure.strengthtraining.traditional",
            isFavorite: true,
            exercises: [
                makeExercise("Weighted Pull-Up", muscle: "Back", sets: [(15, 8, true), (20, 6, true), (20, 6, true)], effort: 8),
                makeExercise("Barbell Bent-Over Row", muscle: "Back", sets: [(85, 8, true), (90, 8, true), (95, 6, true)], effort: 8),
                makeExercise("Wide-Grip Lat Pulldown", muscle: "Back", sets: [(75, 10, true), (80, 10, true), (82.5, 8, true)], effort: 7),
                makeExercise("Incline Dumbbell Curl", muscle: "Arms", sets: [(18, 12, true), (20, 10, true), (20, 10, true)], effort: 7)
            ]
        )

        // 42 hours ago: Legs & Core
        insertCompletedWorkout(
            title: "Legs — Quad & Glute Focus",
            hoursAgo: 44,
            durationMin: 62,
            icon: "bolt.fill",
            isFavorite: true,
            exercises: [
                makeExercise("Barbell Back Squat", muscle: "Legs", sets: [(125, 8, true), (135, 6, true), (142.5, 5, true)], effort: 8),
                makeExercise("Romanian Deadlift", muscle: "Legs", sets: [(115, 8, true), (125, 8, true), (130, 6, true)], effort: 7),
                makeExercise("Leg Press", muscle: "Legs", sets: [(220, 10, true), (240, 10, true), (260, 8, true)], effort: 8),
                makeExercise("Hanging Leg Raise", muscle: "Core", sets: [(15, 12, true), (15, 12, true), (15, 12, true)], effort: 7)
            ]
        )

        // 68 hours ago: Push — Chest & Delts (fully recovered ~94%!)
        insertCompletedWorkout(
            title: "Push — Chest & Delts",
            hoursAgo: 68,
            durationMin: 54,
            icon: "dumbbell.fill",
            isFavorite: true,
            exercises: [
                makeExercise("Barbell Bench Press", muscle: "Chest", sets: [(92.5, 8, true), (97.5, 6, true), (102.5, 5, true)], effort: 8),
                makeExercise("Incline Dumbbell Press", muscle: "Chest", sets: [(36, 10, true), (38, 8, true), (40, 8, true)], effort: 8),
                makeExercise("Seated Dumbbell Shoulder Press", muscle: "Shoulders", sets: [(30, 10, true), (32, 8, true), (34, 8, true)], effort: 8),
                makeExercise("Cable Lateral Raise", muscle: "Shoulders", sets: [(14, 15, true), (16, 12, true), (16, 12, true)], effort: 7)
            ]
        )

        // Earlier workouts across the last 4 weeks for rich charts & streak
        let historicalOffsets: [(Double, String, Double, Double)] = [
            (92, "Upper Body Power", 97.5, 132.5),
            (118, "Full Body Athletic", 95.0, 130.0),
            (164, "Push — Chest & Delts", 95.0, 130.0),
            (190, "Pull — V-Taper Back", 92.5, 127.5),
            (236, "Legs — Quad & Glute Focus", 92.5, 127.5),
            (284, "Upper Body Power", 90.0, 125.0),
            (332, "Push — Chest & Delts", 87.5, 122.5),
            (404, "Pull — V-Taper Back", 87.5, 120.0),
            (476, "Legs — Quad & Glute Focus", 85.0, 117.5),
            (548, "Upper Body Power", 82.5, 115.0)
        ]

        for (idx, item) in historicalOffsets.enumerated() {
            let (hours, title, benchW, squatW) = item
            insertCompletedWorkout(
                title: title,
                hoursAgo: hours,
                durationMin: 50 + (idx % 3) * 4,
                icon: idx % 2 == 0 ? "dumbbell.fill" : "flame.fill",
                exercises: [
                    makeExercise("Barbell Bench Press", muscle: "Chest", sets: [(benchW - 5, 8, true), (benchW, 6, true), (benchW, 6, true)]),
                    makeExercise("Barbell Back Squat", muscle: "Legs", sets: [(squatW - 10, 8, true), (squatW, 6, true), (squatW, 5, true)]),
                    makeExercise("Barbell Bent-Over Row", muscle: "Back", sets: [(80, 8, true), (85, 8, true), (87.5, 6, true)]),
                    makeExercise("Seated Dumbbell Shoulder Press", muscle: "Shoulders", sets: [(28, 10, true), (30, 8, true), (32, 8, true)])
                ]
            )
        }

        // 3. Optional Active Workout Session when capturing Live Workout screen
        if asoRoute == "active_workout" {
            let activeStart = now.addingTimeInterval(-32 * 60)
            let activeBench = makeExercise(
                "Barbell Bench Press",
                muscle: "Chest",
                sets: [
                    (85, 10, true),
                    (95, 8, true),
                    (102.5, 6, true),
                    (105, 5, false)
                ],
                effort: 8,
                rest: 90
            )
            let activeIncline = makeExercise(
                "Incline Dumbbell Press",
                muscle: "Chest",
                sets: [
                    (36, 10, true),
                    (38, 8, true),
                    (40, 8, false)
                ],
                effort: 8,
                rest: 90
            )
            let activeLaterals = makeExercise(
                "Cable Lateral Raise",
                muscle: "Shoulders",
                sets: [
                    (14, 15, true),
                    (16, 12, false),
                    (16, 12, false)
                ],
                effort: 7,
                rest: 60
            )
            let activeWorkout = Workout(
                title: "Push — Chest & Delts",
                date: activeStart,
                endTime: nil,
                icon: "dumbbell.fill",
                exercises: [activeBench, activeIncline, activeLaterals]
            )
            ctx.insert(activeWorkout)
            restTimerManager?.startRestTimer(duration: 68, exerciseName: "Barbell Bench Press", upcomingWeight: "105 kg")
        } else {
            restTimerManager?.stopRestTimer()
        }

        // 4. Weight entries & Goals
        let weights: [(Int, Double)] = [
            (35, 81.6), (28, 81.1), (21, 80.7), (14, 80.2), (10, 79.9), (5, 79.6), (1, 79.4)
        ]
        for (daysAgo, kg) in weights {
            if let d = cal.date(byAdding: .day, value: -daysAgo, to: now) {
                ctx.insert(WeightEntry(date: d, weight: kg))
            }
        }

        if let targetDate = cal.date(byAdding: .day, value: 30, to: now) {
            ctx.insert(UserGoal(type: .strength, targetValue: 110.0, startingValue: 90.0, targetDate: targetDate, exerciseName: "Barbell Bench Press", targetReps: 5))
            ctx.insert(UserGoal(type: .bodyweight, targetValue: 78.0, startingValue: 81.6, targetDate: targetDate))
        }

        try? ctx.save()

        // Route tab selection
        switch asoRoute {
        case "overview":
            di.appState.selectedTab = 0
        case "history":
            di.appState.selectedTab = 1
        case "hub", "discovery", "templates", "active_workout", "smart_builder", "explore":
            di.appState.selectedTab = 2
        case "aihub":
            di.appState.selectedTab = 3
        case "progress":
            di.appState.selectedTab = 4
        default:
            break
        }

        dashboardViewModel?.todaySteps = 9480
        dashboardViewModel?.todayWaterLiters = 2.4
        dashboardViewModel?.refreshAllCaches()
    }
}

//
//  WorkoutModels.swift
//  WorkoutTracker
//

import Foundation
import SwiftData
internal import SwiftUI

// MARK: - Core Data Transfer Objects (DTOs)
struct DashboardCacheDTO: Sendable {
    let personalRecords: [String: Double]
    let lastPerformances: [String: Data]
    let recoveryStatus: [MuscleRecoveryStatus]
    let dashboardMuscleData: [MuscleCountDTO]
    let dashboardTotalExercises: Int
    let dashboardTopExercises: [ExerciseCountDTO]
    let streakCount: Int
    let bestWeekStats: PeriodStats
    let bestMonthStats: PeriodStats
    let weakPoints: [WeakPoint]
    let recommendations: [Recommendation]
}
public struct ExerciseRecordsDTO: Sendable {
    let maxSetReps: Int
    let maxWorkoutReps: Int
    let maxSetVolume: Double
    let maxWorkoutVolume: Double
}

// Обновите существующую структуру ExerciseHistoryPayload
struct ExerciseHistoryPayload: Sendable {
    let type: ExerciseType
    let category: ExerciseCategory
    let muscleGroup: String
    let dataPoints: [ExerciseHistoryDataPoint]
    let trend: ExerciseTrend?
    let forecast: ProgressForecast?
    let records: ExerciseRecordsDTO? // ✅ ДОБАВЛЕНО
}
struct MuscleCountDTO: Sendable { let muscle: String; let count: Int }
struct ExerciseCountDTO: Sendable { let name: String; let count: Int }


struct ExerciseHistoryDataPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let value: Double
    let rawWorkoutID: PersistentIdentifier
}

struct StatsDataResultDTO: Sendable {
    let currentStats: PeriodStats
    let previousStats: PeriodStats
    let recentPRs: [PersonalRecord]
    let detailedComparison: [DetailedComparison]
    let chartData: [ChartDataPoint]
}

struct ExerciseChartDTO: Sendable, Identifiable {
    let id: UUID
    let name: String
    let maxWeight: Double
}

struct WorkoutAnalyticsDataDTO: Sendable {
    var intensity: [String: Int] = [:]
    var volume: Double = 0.0
    var chartExercises: [ExerciseChartDTO] = []
    var completedSetsCount: Int = 0 // ✅ FIX: Added dedicated property for reactive UI updates
}

// MARK: - Common UI & Data Models
struct BestResult: Identifiable, Sendable { let id = UUID(); let exerciseName: String; let value: String; let date: Date; let type: ExerciseType }
struct ChartDataPoint: Identifiable, Sendable { let id = UUID(); let label: String; let value: Double; let rawWorkoutID: PersistentIdentifier? = nil }
struct PersonalRecord: Identifiable, Hashable, Sendable { let id = UUID(); let exerciseName: String; let weight: Double; let date: Date }
struct ExerciseTrend: Identifiable, Sendable { let id = UUID(); let exerciseName: String; let trend: TrendDirection; let changePercentage: Double; let currentValue: Double; let previousValue: Double; let period: String }

enum TrendDirection: Sendable { case growing, declining, stable
    var icon: String { self == .growing ? "arrow.up.right" : self == .declining ? "arrow.down.right" : "arrow.right" }
    var color: Color { self == .growing ? .green : self == .declining ? .red : .orange }
}

struct ProgressForecast: Identifiable, Sendable { let id = UUID(); let exerciseName: String; let currentMax: Double; let predictedMax: Double; let confidence: Int; let timeframe: String }
struct DetailedComparison: Sendable { let metric: String; let currentValue: Double; let previousValue: Double; let change: Double; let changePercentage: Double; let trend: TrendDirection }
struct PeriodStats: Sendable { var workoutCount = 0; var totalReps = 0; var totalDuration = 0; var totalVolume = 0.0; var totalDistance = 0.0 }
struct MuscleRecoveryStatus: Sendable { var muscleGroup: String; var recoveryPercentage: Int }
struct WeakPoint: Identifiable, Sendable { var id = UUID(); let muscleGroup: String; let frequency: Int; var averageVolume: Double; var recommendation: String }
struct Recommendation: Identifiable, Sendable { var id = UUID(); let type: RecommendationType; let title: String; let message: String; let priority: Int }

enum RecommendationType: Sendable { case frequency, volume, balance, recovery, progression, positive
    var icon: String { self == .frequency ? "calendar" : self == .volume ? "scalemass" : self == .balance ? "scalemass.2" : self == .recovery ? "bed.double" : self == .progression ? "chart.line.uptrend.xyaxis" : "checkmark.circle.fill" }
    var color: Color { self == .frequency ? .blue : self == .volume ? .purple : self == .balance ? .orange : self == .recovery ? .green : self == .progression ? .pink : .green }
}
struct AppError: Identifiable, Sendable { let id = UUID(); let title: String; let message: String }
enum PRLevel: Int, CaseIterable, Sendable {
    case bronze = 1, silver, gold, diamond
    
    var title: String {
        switch self {
        case .bronze: return String(localized: "Bronze Record!")
        case .silver: return String(localized: "Silver Record!")
        case .gold: return String(localized: "Gold Record!")
        case .diamond: return String(localized: "Diamond Record!")
        }
    }
    
    var rank: Int { self.rawValue }
    
    var angularColors: [Color] {
        switch self {
        case .bronze: return [.brown, .orange, .brown]
        case .silver: return [.gray, .white, .gray]
        case .gold: return [.yellow, .orange, .yellow]
        case .diamond: return [.cyan, .white, .purple, .blue, .cyan]
        }
    }
}
enum WorkoutRepositoryError: Error {
    case modelNotFound
    case invalidData
}

enum DetailDestination: Identifiable, Equatable {
    case shareSheet
    case emptyWorkoutAlert
    case prCelebration(PRLevel)
    case achievementPopup(Achievement)
    case exerciseSelection
    case supersetBuilder(Exercise?)
    case swapExercise(Exercise)
    
    var id: String {
        switch self {
        case .shareSheet: return "share"
        case .emptyWorkoutAlert: return "emptyAlert"
        case .prCelebration: return "pr"
        case .achievementPopup(let a): return "ach_\(a.id)"
        case .exerciseSelection: return "exSel"
        case .supersetBuilder(let ex): return "super_\(ex?.id.uuidString ?? "new")"
        case .swapExercise(let ex): return "swap_\(ex.id.uuidString)"
        }
    }
    
    static func == (lhs: DetailDestination, rhs: DetailDestination) -> Bool {
        return lhs.id == rhs.id
    }
    
    var isSheet: Bool {
        switch self {
        case .shareSheet, .exerciseSelection, .supersetBuilder, .swapExercise: return true
        default: return false
        }
    }
    
    var isFullScreen: Bool {
        switch self {
        case .prCelebration, .achievementPopup: return true
        default: return false
        }
    }
}
public struct ProactiveWorkoutProposal: Sendable {
    let message: String
    let workout: GeneratedWorkoutDTO
}

struct RadarDataPoint: Sendable, Identifiable {
    let id = UUID()
    let axis: String
    let value: Double
    let maxValue: Double
}

struct AnatomyStatsDTO: Sendable {
    let radarData: [RadarDataPoint]
    let heatmapIntensities: [String: Int]
    let setsPerMuscle: [MuscleCountDTO]
}

struct SetsOverTimePoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let muscleGroup: String
    let sets: Int
}
public enum EquipmentCategory: String, Sendable, CaseIterable, Identifiable {
    case freeWeights = "Free Weights"
    case machines = "Machines & Cables"
    case bodyweight = "Bodyweight"
    case other = "Other"
    
    public var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .freeWeights: return "dumbbell.fill"
        case .machines: return "gearshape.2.fill"
        case .bodyweight: return "figure.core.training"
        case .other: return "circle.grid.cross"
        }
    }
    
    var color: Color {
        switch self {
        case .freeWeights: return .orange
        case .machines: return .purple
        case .bodyweight: return .cyan
        case .other: return .gray
        }
    }
}

public struct TrainingStyleDTO: Sendable {
    let compoundSets: Int
    let isolationSets: Int
    let equipmentDistribution: [EquipmentCategory: Int]
    
    var totalMechanicSets: Int { compoundSets + isolationSets }
    var totalEquipmentSets: Int { equipmentDistribution.values.reduce(0, +) }
}

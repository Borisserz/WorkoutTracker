//
//  AITrackerEngine.swift
//  WorkoutTracker
//
//  Vision & Biomechanics Engine
//  Combines deterministic geometric heuristics with ML safeguards.
//

import Foundation
import Vision
import CoreGraphics
import Combine

// MARK: - 1. Biomechanics Core Models (Thread-Safe)

/// Универсальные названия суставов, независимые от стороны (лево/право)
public enum AgnosticJointName: Sendable {
    case neck, root
    case shoulder, elbow, wrist
    case hip, knee, ankle
}

public enum MovementMetric: Sendable {
    case angle(AgnosticJointName, AgnosticJointName, AgnosticJointName)
    case distance(AgnosticJointName, AgnosticJointName)
    case projectionY(AgnosticJointName, AgnosticJointName)
    indirect case fallback(primary: MovementMetric, secondary: MovementMetric)
}

public struct PhaseThresholds: Sendable {
    public let relaxed: Double
    public let contracted: Double
    public let hysteresis: Double
}

public struct PhaseTexts: Sendable {
    public let contracting: String
    public let contracted: String
    public let extending: String
    public let relaxed: String
}

public struct BiomechanicsProfile: Sendable {
    public let exerciseName: String
    public let metric: MovementMetric
    public let thresholds: PhaseThresholds
    public let maxOccludedFrames: Int
    public let primaryMuscles: [String]
    public let secondaryMuscles: [String]
    public let texts: PhaseTexts
}

// MARK: - 2. Biomechanics Math

public enum BiomechanicsMath {
    
    /// Извлекает самые уверенные точки, автоматически выбирая левую или правую сторону
    public static func extractAgnosticJoints(from points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> [AgnosticJointName: CGPoint] {
        var agnostic: [AgnosticJointName: CGPoint] = [:]
        
        let leftScore = [points[.leftShoulder], points[.leftElbow], points[.leftWrist], points[.leftHip], points[.leftKnee], points[.leftAnkle]]
            .compactMap { $0?.confidence }.reduce(0, +)
        let rightScore = [points[.rightShoulder], points[.rightElbow], points[.rightWrist], points[.rightHip], points[.rightKnee], points[.rightAnkle]]
            .compactMap { $0?.confidence }.reduce(0, +)
        
        let isLeft = leftScore >= rightScore
        let threshold: Float = 0.3
        
        func add(_ name: AgnosticJointName, left: VNHumanBodyPoseObservation.JointName, right: VNHumanBodyPoseObservation.JointName) {
            let target = isLeft ? left : right
            if let pt = points[target], pt.confidence > threshold {
                // Инвертируем Y для удобной работы в системе координат UI
                agnostic[name] = CGPoint(x: pt.location.x, y: 1.0 - pt.location.y)
            }
        }
        
        add(.shoulder, left: .leftShoulder, right: .rightShoulder)
        add(.elbow, left: .leftElbow, right: .rightElbow)
        add(.wrist, left: .leftWrist, right: .rightWrist)
        add(.hip, left: .leftHip, right: .rightHip)
        add(.knee, left: .leftKnee, right: .rightKnee)
        add(.ankle, left: .leftAnkle, right: .rightAnkle)
        
        if let neck = points[.neck] ?? points[.nose], neck.confidence > threshold {
            agnostic[.neck] = CGPoint(x: neck.location.x, y: 1.0 - neck.location.y)
        }
        if let root = points[.root], root.confidence > threshold {
            agnostic[.root] = CGPoint(x: root.location.x, y: 1.0 - root.location.y)
        }
        
        return agnostic
    }
    // Вставь этот код внутрь enum BiomechanicsMath
    public static func distance(p1: CGPoint, p2: CGPoint) -> Double {
        return hypot(p1.x - p2.x, p1.y - p2.y)
    }
    public static func angleBetween(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
        let v1 = CGVector(dx: p1.x - p2.x, dy: p1.y - p2.y)
        let v2 = CGVector(dx: p3.x - p2.x, dy: p3.y - p2.y)
        
        let dotProduct = (v1.dx * v2.dx) + (v1.dy * v2.dy)
        let magnitude1 = hypot(v1.dx, v1.dy)
        let magnitude2 = hypot(v2.dx, v2.dy)
        guard magnitude1 > 0, magnitude2 > 0 else { return 0.0 }
        
        let cosineAngle = max(-1.0, min(1.0, dotProduct / (magnitude1 * magnitude2)))
        return acos(cosineAngle) * (180.0 / .pi)
    }
    
    public static func projectedDistanceY(p1: CGPoint, p2: CGPoint) -> Double {
        return abs(p1.y - p2.y)
    }
    
    public static func amplitudePercentage(current: Double, relaxed: Double, contracted: Double) -> Double {
        let totalRange = contracted - relaxed
        guard totalRange != 0 else { return 0.0 }
        let progress = (current - relaxed) / totalRange
        return max(0.0, min(100.0, progress * 100.0))
    }
}

// MARK: - 3. Exercise Registry (Factory)

public enum ExerciseRegistry {
    public static func profile(for exercise: String) -> BiomechanicsProfile? {
        let name = exercise.lowercased()
        if name.contains("curl") { return bicepsCurl }
        if name.contains("squat") { return squat }
        if name.contains("bench") || name.contains("press") { return benchPress }
        return nil // Фоллбэк: упражнение не поддерживается ИИ
    }
    
    private static var bicepsCurl: BiomechanicsProfile {
        BiomechanicsProfile(
            exerciseName: "Biceps Curl",
            metric: .angle(.shoulder, .elbow, .wrist),
            thresholds: PhaseThresholds(relaxed: 160.0, contracted: 45.0, hysteresis: 15.0),
            maxOccludedFrames: 3,
            primaryMuscles: ["biceps"], secondaryMuscles: ["forearm"],
            texts: PhaseTexts(contracting: "Curl up!", contracted: "Squeeze!", extending: "Control down...", relaxed: "Ready")
        )
    }
    
    private static var squat: BiomechanicsProfile {
        BiomechanicsProfile(
            exerciseName: "Squat",
            metric: .fallback(primary: .angle(.hip, .knee, .ankle), secondary: .angle(.shoulder, .hip, .knee)),
            thresholds: PhaseThresholds(relaxed: 165.0, contracted: 90.0, hysteresis: 15.0),
            maxOccludedFrames: 4,
            primaryMuscles: ["quadriceps", "gluteal"], secondaryMuscles: ["hamstring", "calves"],
            texts: PhaseTexts(contracting: "Lower...", contracted: "Push up!", extending: "Stand tall", relaxed: "Ready")
        )
    }
    
    private static var benchPress: BiomechanicsProfile {
        BiomechanicsProfile(
            exerciseName: "Bench Press",
            metric: .projectionY(.wrist, .shoulder),
            thresholds: PhaseThresholds(relaxed: 0.45, contracted: 0.10, hysteresis: 0.05),
            maxOccludedFrames: 3,
            primaryMuscles: ["chest", "triceps"], secondaryMuscles: ["deltoids"],
            texts: PhaseTexts(contracting: "Lower bar...", contracted: "Press!", extending: "Lock out", relaxed: "Ready")
        )
    }
}

// MARK: - 4. Repetition Tracker (State Machine)

public enum MovementPhase: Sendable {
    case relaxed, contracting, contracted, extending, unknown
}

public struct TrackingState: Sendable {
    public var phase: MovementPhase = .unknown
    public var repsCount: Int = 0
    public var currentAmplitude: Double = 0.0
    
    fileprivate var missingFramesCount: Int = 0
    fileprivate var lastValidMetricValue: Double? = nil
}

public final class RepetitionTracker {
    private let profile: BiomechanicsProfile
    private(set) var state: TrackingState
    
    public init(profile: BiomechanicsProfile) {
        self.profile = profile
        self.state = TrackingState()
    }
    
    public func process(joints: [AgnosticJointName: CGPoint]) -> TrackingState {
        guard let metricValue = extractMetricValue(profile.metric, from: joints) else {
            return handleOcclusion()
        }
        
        state.missingFramesCount = 0
        state.lastValidMetricValue = metricValue
        
        state.currentAmplitude = BiomechanicsMath.amplitudePercentage(
            current: metricValue,
            relaxed: profile.thresholds.relaxed,
            contracted: profile.thresholds.contracted
        )
        
        updatePhase(with: metricValue)
        return state
    }
    
    private func handleOcclusion() -> TrackingState {
        state.missingFramesCount += 1
        if state.missingFramesCount > profile.maxOccludedFrames {
            state.phase = .unknown
            state.currentAmplitude = 0.0
            state.lastValidMetricValue = nil
        }
        return state
    }
    
    private func updatePhase(with value: Double) {
        let t = profile.thresholds
        let isDecreasing = t.contracted < t.relaxed
        
        let reachedContracted = isDecreasing ? (value <= t.contracted + t.hysteresis) : (value >= t.contracted - t.hysteresis)
        let reachedRelaxed = isDecreasing ? (value >= t.relaxed - t.hysteresis) : (value <= t.relaxed + t.hysteresis)
        
        switch state.phase {
        case .unknown, .relaxed:
            if !reachedRelaxed { state.phase = .contracting }
        case .contracting:
            if reachedContracted { state.phase = .contracted }
            else if reachedRelaxed { state.phase = .relaxed } // False start
        case .contracted:
            if !reachedContracted { state.phase = .extending }
        case .extending:
            if reachedRelaxed {
                state.phase = .relaxed
                state.repsCount += 1 // ✅ Повторение засчитано!
            } else if reachedContracted {
                state.phase = .contracted // Bounce back
            }
        }
    }
    
    private func extractMetricValue(_ metric: MovementMetric, from joints: [AgnosticJointName: CGPoint]) -> Double? {
        switch metric {
        case .angle(let j1, let j2, let j3):
            guard let p1 = joints[j1], let p2 = joints[j2], let p3 = joints[j3] else { return nil }
            return BiomechanicsMath.angleBetween(p1: p1, p2: p2, p3: p3)
        case .distance(let j1, let j2):
            guard let p1 = joints[j1], let p2 = joints[j2] else { return nil }
            return BiomechanicsMath.distance(p1: p1, p2: p2)
        case .projectionY(let j1, let j2):
            guard let p1 = joints[j1], let p2 = joints[j2] else { return nil }
            return BiomechanicsMath.projectedDistanceY(p1: p1, p2: p2)
        case .fallback(let primary, let secondary):
            return extractMetricValue(primary, from: joints) ?? extractMetricValue(secondary, from: joints)
        }
    }
}

// MARK: - 5. AITrackerEngine (Main Coordinator)

@MainActor
public final class AITrackerEngine: ObservableObject {
    
    // MARK: - Published UI State
    @Published public private(set) var repsCount: Int = 0
    @Published public private(set) var feedbackMessage: String = "Initializing..."
    @Published public private(set) var isTrackingAction: Bool = false
    @Published public var liveMuscleTension: [String: Int] = [:]
    
    // MARK: - Private Core Components
    private let exerciseName: String
    private let profile: BiomechanicsProfile? // Кэшируем профиль, чтобы не искать каждый кадр
    private let mlEngine = MLWorkoutEngine()
    private var repetitionTracker: RepetitionTracker?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    public init(exerciseName: String) {
        self.exerciseName = exerciseName
        self.profile = ExerciseRegistry.profile(for: exerciseName)
        
        if let profile = self.profile {
            self.repetitionTracker = RepetitionTracker(profile: profile)
            self.feedbackMessage = "Ready. Waiting for action."
        } else {
            self.feedbackMessage = "AI Tracking not optimized for this exercise"
        }
        
        setupMLSubscription()
    }
    
    // MARK: - Pipeline
    
    private func setupMLSubscription() {
        mlEngine.$currentAction
            .dropFirst()
            .sink { [weak self] action in
                self?.handleMLActionChange(action: action)
            }
            .store(in: &cancellables)
    }
    
    private func handleMLActionChange(action: String) {
        guard repetitionTracker != nil else { return }
        
        // Считаем активным, если ML выдает "Active" или точное название упражнения
        let isActive = action.lowercased() == "active" ||
                       exerciseName.lowercased().contains(action.lowercased())
        
        if isTrackingAction != isActive {
            isTrackingAction = isActive
            
            if !isActive {
                feedbackMessage = "Adjust form / Waiting..."
                liveMuscleTension.removeAll()
            }
        }
    }
    
    public func processFrame(observation: VNHumanBodyPoseObservation) {
        guard let tracker = repetitionTracker, let profile = self.profile else { return }
        
        // 1. Всегда кормим ML Engine для поддержания окна предикшенов
        mlEngine.processFrame(observation: observation)
        
        // 2. Если ML запрещает трекинг, ставим математику на паузу
        // 2. Если ML запрещает трекинг, ставим математику на паузу
        // guard isTrackingAction else { return } // ВРЕМЕННО ОТКЛЮЧЕНО ДЛЯ ТЕСТА
        
        // 3. Извлекаем сырые точки и конвертируем в агностичные
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        let agnosticJoints = BiomechanicsMath.extractAgnosticJoints(from: recognizedPoints)
        
        // 4. Прогоняем через математический трекер
        let state = tracker.process(joints: agnosticJoints)
        
        // 5. Синхронизируем состояние с UI
        syncStateToUI(state: state, profile: profile)
    }
    
    // MARK: - State Synchronization

        
        private func syncStateToUI(state: TrackingState, profile: BiomechanicsProfile) {
            // Синхронизация повторений
            if self.repsCount != state.repsCount {
                self.repsCount = state.repsCount
            }
            
            // Обновление Heatmap Tension
            let tension = Int(state.currentAmplitude)
            var newTension: [String: Int] = [:]
            
            if tension > 0 {
                for m in profile.primaryMuscles { newTension[m] = tension }
                for m in profile.secondaryMuscles { newTension[m] = tension / 2 }
            }
            self.liveMuscleTension = newTension
            
            // Обратная связь по State Machine
            let newFeedback: String
            switch state.phase {
            case .relaxed:
                newFeedback = "Ready"
            case .contracting, .contracted, .extending:
                newFeedback = "Tracking..."
            case .unknown:
                newFeedback = "Body parts occluded. Adjust camera!"
            }
            
            if self.feedbackMessage != newFeedback {
                self.feedbackMessage = newFeedback
            }
        }
    
    public func reset() {
        self.repsCount = 0
        self.liveMuscleTension.removeAll()
        self.isTrackingAction = false
        self.mlEngine.reset()
        
        if let profile = self.profile {
            self.repetitionTracker = RepetitionTracker(profile: profile)
            self.feedbackMessage = "Ready. Waiting for action."
        }
    }
}

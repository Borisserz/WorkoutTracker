// ============================================================
// FILE: WorkoutTracker/MlVision/AITrackerEngine.swift
// ============================================================

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

public enum ExerciseRegistry: Sendable {
    
    /// O(1) Фабрика. Получает паттерн из базы и возвращает готовый математический профиль
    public static func profile(for pattern: MovementPattern, exerciseName: String) -> BiomechanicsProfile? {
        switch pattern {
        case .elbowFlexion: return bicepsCurl(name: exerciseName)
        case .squat: return squatPattern(name: exerciseName)
        case .horizontalPress: return horizontalPress(name: exerciseName)
        case .verticalPull: return verticalPull(name: exerciseName)
        case .horizontalPull: return horizontalPull(name: exerciseName)
        case .verticalPress: return verticalPress(name: exerciseName)
        case .hinge: return hingePattern(name: exerciseName)
        case .lunge: return lungePattern(name: exerciseName)
        case .elbowExtension: return tricepsExtension(name: exerciseName)
        case .coreFlexion: return coreFlexion(name: exerciseName)
        case .lateralRaise: return lateralRaise(name: exerciseName)
        case .calfRaise: return calfRaise(name: exerciseName)
        case .unsupported: return nil
        }
    }
    
    // MARK: - Biomechanical Profiles
    
    private static func bicepsCurl(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .angle(.shoulder, .elbow, .wrist), thresholds: PhaseThresholds(relaxed: 160.0, contracted: 50.0, hysteresis: 15.0), maxOccludedFrames: 3, primaryMuscles: ["biceps"], secondaryMuscles: ["forearm"], texts: PhaseTexts(contracting: "Curl it up!", contracted: "Squeeze!", extending: "Control...", relaxed: "Ready"))
    }
    
    private static func squatPattern(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .fallback(primary: .angle(.hip, .knee, .ankle), secondary: .angle(.shoulder, .hip, .knee)), thresholds: PhaseThresholds(relaxed: 165.0, contracted: 90.0, hysteresis: 15.0), maxOccludedFrames: 4, primaryMuscles: ["quadriceps", "gluteal"], secondaryMuscles: ["hamstring", "lower-back", "calves"], texts: PhaseTexts(contracting: "Lower deep...", contracted: "Drive up!", extending: "Stand tall", relaxed: "Ready"))
    }
    
    private static func horizontalPress(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .angle(.shoulder, .elbow, .wrist), thresholds: PhaseThresholds(relaxed: 160.0, contracted: 75.0, hysteresis: 15.0), maxOccludedFrames: 3, primaryMuscles: ["chest", "triceps"], secondaryMuscles: ["deltoids"], texts: PhaseTexts(contracting: "Lower slowly...", contracted: "Press hard!", extending: "Lock out", relaxed: "Arms straight"))
    }
    
    private static func verticalPull(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .projectionY(.wrist, .shoulder), thresholds: PhaseThresholds(relaxed: 0.40, contracted: 0.10, hysteresis: 0.05), maxOccludedFrames: 3, primaryMuscles: ["upper-back", "lats", "biceps"], secondaryMuscles: ["forearm", "deltoids"], texts: PhaseTexts(contracting: "Pull up!", contracted: "Hold it!", extending: "Lower under control", relaxed: "Dead hang"))
    }
    
    private static func horizontalPull(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .angle(.shoulder, .elbow, .wrist), thresholds: PhaseThresholds(relaxed: 165.0, contracted: 85.0, hysteresis: 15.0), maxOccludedFrames: 3, primaryMuscles: ["upper-back", "lats"], secondaryMuscles: ["biceps", "lower-back", "deltoids"], texts: PhaseTexts(contracting: "Pull to torso!", contracted: "Squeeze back", extending: "Stretch", relaxed: "Arms extended"))
    }
    
    private static func verticalPress(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .angle(.shoulder, .elbow, .wrist), thresholds: PhaseThresholds(relaxed: 60.0, contracted: 160.0, hysteresis: 15.0), maxOccludedFrames: 3, primaryMuscles: ["deltoids", "triceps"], secondaryMuscles: ["trapezius"], texts: PhaseTexts(contracting: "Press overhead!", contracted: "Locked out", extending: "Lower safely", relaxed: "Ready"))
    }
    
    private static func hingePattern(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .angle(.shoulder, .hip, .knee), thresholds: PhaseThresholds(relaxed: 170.0, contracted: 90.0, hysteresis: 15.0), maxOccludedFrames: 4, primaryMuscles: ["hamstring", "gluteal", "lower-back"], secondaryMuscles: ["trapezius", "forearm"], texts: PhaseTexts(contracting: "Hinge hips...", contracted: "Thrust hips!", extending: "Lock hips", relaxed: "Standing tall"))
    }
    
    private static func lungePattern(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .angle(.hip, .knee, .ankle), thresholds: PhaseThresholds(relaxed: 170.0, contracted: 90.0, hysteresis: 15.0), maxOccludedFrames: 4, primaryMuscles: ["quadriceps", "gluteal", "hamstring"], secondaryMuscles: ["calves"], texts: PhaseTexts(contracting: "Drop knee...", contracted: "Push through heel!", extending: "Rise up", relaxed: "Feet together"))
    }
    
    private static func tricepsExtension(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .angle(.shoulder, .elbow, .wrist), thresholds: PhaseThresholds(relaxed: 60.0, contracted: 165.0, hysteresis: 15.0), maxOccludedFrames: 3, primaryMuscles: ["triceps"], secondaryMuscles: ["deltoids"], texts: PhaseTexts(contracting: "Extend arms!", contracted: "Flex triceps", extending: "Control", relaxed: "Elbows bent"))
    }
    
    private static func coreFlexion(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .angle(.shoulder, .hip, .knee), thresholds: PhaseThresholds(relaxed: 170.0, contracted: 90.0, hysteresis: 15.0), maxOccludedFrames: 3, primaryMuscles: ["abs"], secondaryMuscles: ["obliques"], texts: PhaseTexts(contracting: "Crunch up!", contracted: "Hold core tight", extending: "Lower down", relaxed: "Body extended"))
    }
    
    private static func lateralRaise(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .angle(.hip, .shoulder, .elbow), thresholds: PhaseThresholds(relaxed: 15.0, contracted: 85.0, hysteresis: 10.0), maxOccludedFrames: 3, primaryMuscles: ["deltoids"], secondaryMuscles: ["trapezius", "upper-back"], texts: PhaseTexts(contracting: "Raise arms!", contracted: "Hold the burn", extending: "Lower slowly", relaxed: "Arms down"))
    }
    
    private static func calfRaise(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name, metric: .distance(.knee, .ankle), thresholds: PhaseThresholds(relaxed: 0.35, contracted: 0.40, hysteresis: 0.01), maxOccludedFrames: 3, primaryMuscles: ["calves"], secondaryMuscles: [], texts: PhaseTexts(contracting: "Up on toes!", contracted: "Peak contraction", extending: "Heels down", relaxed: "Heels flat"))
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
    
    // VBT (Velocity-Based Training) Properties
    public var concentricStartTime: Date? = nil
    public var concentricDurations: [TimeInterval] = []
    public var isVBTWarningTriggered: Bool = false
    
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
            if !reachedRelaxed {
                state.phase = .contracting
                state.concentricStartTime = Date()
            }
        case .contracting:
            if reachedContracted {
                state.phase = .contracted
                if let start = state.concentricStartTime {
                    let duration = Date().timeIntervalSince(start)
                    state.concentricDurations.append(duration)
                    if state.concentricDurations.count >= 3 && !state.isVBTWarningTriggered {
                        let baseline = (state.concentricDurations[0] + state.concentricDurations[1]) / 2.0
                        if duration >= baseline * 1.20 { state.isVBTWarningTriggered = true }
                    }
                }
            } else if reachedRelaxed { state.phase = .relaxed }
        case .contracted:
            if !reachedContracted { state.phase = .extending }
        case .extending:
            if reachedRelaxed {
                state.phase = .relaxed
                state.repsCount += 1
            } else if reachedContracted {
                state.phase = .contracted
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


// MARK: - 5. Main Coordinator (AITrackerEngine)

@MainActor
public final class AITrackerEngine: ObservableObject {
    
    // MARK: - Published UI State
    @Published public private(set) var repsCount: Int = 0
    @Published public private(set) var feedbackMessage: String = "Initializing AI..."
    @Published public private(set) var isTrackingAction: Bool = false
    @Published public var liveMuscleTension: [String: Int] = [:]
    @Published public private(set) var vbtWarningTriggered: Bool = false
    
    // MARK: - Private Core Components
    private let exerciseName: String
    private var profile: BiomechanicsProfile?
    private let mlEngine = MLWorkoutEngine()
    private var repetitionTracker: RepetitionTracker?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    public init(exerciseName: String) {
        self.exerciseName = exerciseName
        setupMLSubscription()
    }
    
    // MARK: - Async Setup
    /// Асинхронно подтягивает профиль упражнения из словаря (O(1))
    public func setup() async {
        // 1. Ищем паттерн в загруженной базе данных
        let pattern = await ExerciseDatabaseService.shared.getPattern(for: exerciseName)
        
        // 2. Фабрика выдает геометрические углы и настройки
        self.profile = ExerciseRegistry.profile(for: pattern, exerciseName: exerciseName)
        
        if let profile = self.profile {
            self.repetitionTracker = RepetitionTracker(profile: profile)
            self.feedbackMessage = "Ready. Waiting for action."
        } else {
            self.feedbackMessage = "AI Tracking not supported for this exercise."
        }
    }
    
    // MARK: - Pipeline
    
    private func setupMLSubscription() {
        // Подписываемся на флаг активности из ML Gatekeeper'а
        mlEngine.$isUserActive
            .dropFirst()
            .sink { [weak self] isActive in
                self?.handleMLActionChange(isActive: isActive)
            }
            .store(in: &cancellables)
    }
    
    private func handleMLActionChange(isActive: Bool) {
        guard repetitionTracker != nil else { return }
        
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
        
        // 1. Всегда кормим ML Gatekeeper для поддержания окна предикшенов
        mlEngine.processFrame(observation: observation)
    
        // 2. Блокируем математику, если Gatekeeper считает, что юзер Restает
        guard isTrackingAction else { return }
        
        // 3. Выполняется ТОЛЬКО если юзер активен (экономия батареи и CPU)
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        let agnosticJoints = BiomechanicsMath.extractAgnosticJoints(from: recognizedPoints)
        
        // 4. Детерминированная математика (< 1 мс)
        let state = tracker.process(joints: agnosticJoints)
        
        // 5. Синхронизация с UI
        syncStateToUI(state: state, profile: profile)
    }
    
    private func syncStateToUI(state: TrackingState, profile: BiomechanicsProfile) {
        if self.repsCount != state.repsCount {
            self.repsCount = state.repsCount
        }
        
        // VBT Trigger Sync (Предупреждение о падении скорости штанги)
        if state.isVBTWarningTriggered && !self.vbtWarningTriggered {
            self.vbtWarningTriggered = true
        }
        
        // Обновление тепловой карты (Live Heatmap Tension)
        let tension = Int(state.currentAmplitude)
        var newTension: [String: Int] = [:]
        
        if tension > 0 {
            for m in profile.primaryMuscles { newTension[m] = tension }
            for m in profile.secondaryMuscles { newTension[m] = tension / 2 }
        }
        self.liveMuscleTension = newTension
        
        // Текстовая обратная связь
        let newFeedback: String
        switch state.phase {
        case .relaxed:
            newFeedback = profile.texts.relaxed
        case .contracting:
            newFeedback = profile.texts.contracting
        case .contracted:
            newFeedback = profile.texts.contracted
        case .extending:
            newFeedback = profile.texts.extending
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

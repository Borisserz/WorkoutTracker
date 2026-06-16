
import Foundation
import Vision
import CoreGraphics
import Combine

// MARK: - Agnostic Joint Mapping

public enum AgnosticJointName: Sendable {
    case neck, root
    case shoulder, elbow, wrist
    case hip, knee, ankle
}

public enum MovementMetric: Sendable {
    case angle(AgnosticJointName, AgnosticJointName, AgnosticJointName)
    case distance(AgnosticJointName, AgnosticJointName)
    case projectionY(AgnosticJointName, AgnosticJointName)
    /// Euclidean distance normalized by torso height (shoulder→hip) — scale-invariant
    case normalizedDistance(AgnosticJointName, AgnosticJointName)
    /// Y-projection normalized by torso height — scale-invariant
    case normalizedProjectionY(AgnosticJointName, AgnosticJointName)
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

// MARK: - Side Selector
// ✅ УЛУЧШЕНИЕ: Отслеживает лучшую сторону тела с EMA-сглаживанием.
// Предотвращает мигание между левой и правой стороной при движении.

final class SideSelector {
    private var leftScore: Float = 0
    private var rightScore: Float = 0
    /// Насколько сильно придерживаться предыдущего выбора (stability bias)
    private let smoothingAlpha: Float = 0.25
    /// Минимальный перевес для смены стороны — предотвращает флуктуации
    private let switchHysteresis: Float = 0.3

    private(set) var preferLeft: Bool = true

    func update(points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        let leftJoints: [VNHumanBodyPoseObservation.JointName] =
            [.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle]
        let rightJoints: [VNHumanBodyPoseObservation.JointName] =
            [.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle]

        let rawLeft  = leftJoints.compactMap  { points[$0]?.confidence }.reduce(0, +)
        let rawRight = rightJoints.compactMap { points[$0]?.confidence }.reduce(0, +)

        // EMA сглаживание оценок сторон
        leftScore  = smoothingAlpha * rawLeft  + (1 - smoothingAlpha) * leftScore
        rightScore = smoothingAlpha * rawRight + (1 - smoothingAlpha) * rightScore

        // Переключаем сторону только если другая ЗНАЧИТЕЛЬНО лучше (hysteresis)
        if preferLeft && rightScore > leftScore + switchHysteresis {
            preferLeft = false
        } else if !preferLeft && leftScore > rightScore + switchHysteresis {
            preferLeft = true
        }
    }
}

// MARK: - Biomechanics Math

public enum BiomechanicsMath {

    /// Извлекает агностические суставы, используя заданный выбор стороны.
    /// preferLeft = nil → автовыбор (для обратной совместимости)
    public static func extractAgnosticJoints(
        from points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        preferLeft: Bool? = nil
    ) -> [AgnosticJointName: CGPoint] {
        var agnostic: [AgnosticJointName: CGPoint] = [:]

        let isLeft: Bool
        if let forced = preferLeft {
            isLeft = forced
        } else {
            // Fallback: автовыбор по сумме уверенности
            let lScore = [points[.leftShoulder], points[.leftElbow], points[.leftWrist],
                          points[.leftHip], points[.leftKnee], points[.leftAnkle]]
                .compactMap { $0?.confidence }.reduce(0, +)
            let rScore = [points[.rightShoulder], points[.rightElbow], points[.rightWrist],
                          points[.rightHip], points[.rightKnee], points[.rightAnkle]]
                .compactMap { $0?.confidence }.reduce(0, +)
            isLeft = lScore >= rScore
        }

        let threshold: Float = 0.2

        func add(_ name: AgnosticJointName,
                 left: VNHumanBodyPoseObservation.JointName,
                 right: VNHumanBodyPoseObservation.JointName) {
            let target = isLeft ? left : right
            if let pt = points[target], pt.confidence > threshold {
                agnostic[name] = CGPoint(x: pt.location.x, y: 1.0 - pt.location.y)
            }
        }

        add(.shoulder, left: .leftShoulder, right: .rightShoulder)
        add(.elbow,    left: .leftElbow,    right: .rightElbow)
        add(.wrist,    left: .leftWrist,    right: .rightWrist)
        add(.hip,      left: .leftHip,      right: .rightHip)
        add(.knee,     left: .leftKnee,     right: .rightKnee)
        add(.ankle,    left: .leftAnkle,    right: .rightAnkle)

        if let neck = points[.neck] ?? points[.nose], neck.confidence > threshold {
            agnostic[.neck] = CGPoint(x: neck.location.x, y: 1.0 - neck.location.y)
        }
        if let root = points[.root], root.confidence > threshold {
            agnostic[.root] = CGPoint(x: root.location.x, y: 1.0 - root.location.y)
        }

        return agnostic
    }

    /// Высота торса в нормализованных координатах (shoulder→hip).
    /// Используется для scale-invariant нормализации distance/projectionY метрик.
    public static func torsoHeight(joints: [AgnosticJointName: CGPoint]) -> Double? {
        guard let sh = joints[.shoulder], let hip = joints[.hip] else { return nil }
        let h = distance(p1: sh, p2: hip)
        return h > 0.04 ? h : nil  // минимальный порог — торс должен быть виден
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

// MARK: - Exercise Registry

public enum ExerciseRegistry: Sendable {

    public static func profile(for pattern: MovementPattern, exerciseName: String) -> BiomechanicsProfile? {
        switch pattern {
        case .elbowFlexion:   return bicepsCurl(name: exerciseName)
        case .squat:          return squatPattern(name: exerciseName)
        case .horizontalPress:return horizontalPress(name: exerciseName)
        case .verticalPull:   return verticalPull(name: exerciseName)
        case .horizontalPull: return horizontalPull(name: exerciseName)
        case .verticalPress:  return verticalPress(name: exerciseName)
        case .hinge:          return hingePattern(name: exerciseName)
        case .lunge:          return lungePattern(name: exerciseName)
        case .elbowExtension: return tricepsExtension(name: exerciseName)
        case .coreFlexion:    return coreFlexion(name: exerciseName)
        case .lateralRaise:   return lateralRaise(name: exerciseName)
        case .calfRaise:      return calfRaise(name: exerciseName)
        case .unsupported:    return nil
        }
    }

    private static func bicepsCurl(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .angle(.shoulder, .elbow, .wrist),
            thresholds: PhaseThresholds(relaxed: 160.0, contracted: 50.0, hysteresis: 15.0),
            maxOccludedFrames: 8,
            primaryMuscles: ["biceps"], secondaryMuscles: ["forearm"],
            texts: PhaseTexts(contracting: String(localized: "Crunch"), contracted: String(localized: "Squeeze abs"), extending: String(localized: "Lower back"), relaxed: String(localized: "Lie flat")))
    }

    private static func squatPattern(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .fallback(primary: .angle(.hip, .knee, .ankle), secondary: .angle(.shoulder, .hip, .knee)),
            thresholds: PhaseThresholds(relaxed: 165.0, contracted: 90.0, hysteresis: 15.0),
            maxOccludedFrames: 10,
            primaryMuscles: ["quadriceps", "gluteal"], secondaryMuscles: ["hamstring", "lower-back", "calves"],
            texts: PhaseTexts(contracting: "Lower deep...", contracted: "Drive up!", extending: "Stand tall", relaxed: "Ready"))
    }

    private static func horizontalPress(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .angle(.shoulder, .elbow, .wrist),
            thresholds: PhaseThresholds(relaxed: 160.0, contracted: 75.0, hysteresis: 15.0),
            maxOccludedFrames: 8,
            primaryMuscles: ["chest", "triceps"], secondaryMuscles: ["deltoids"],
            texts: PhaseTexts(contracting: "Lower slowly...", contracted: "Press hard!", extending: "Lock out", relaxed: "Arms straight"))
    }

    private static func verticalPull(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .normalizedProjectionY(.wrist, .shoulder),
            thresholds: PhaseThresholds(relaxed: 1.1, contracted: 0.25, hysteresis: 0.15),
            maxOccludedFrames: 8,
            primaryMuscles: ["upper-back", "lats", "biceps"], secondaryMuscles: ["forearm", "deltoids"],
            texts: PhaseTexts(contracting: String(localized: "Stand up"), contracted: String(localized: "Stand tall"), extending: String(localized: "Hinge forward"), relaxed: String(localized: "Stretch hamstrings")))
    }

    private static func horizontalPull(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .angle(.shoulder, .elbow, .wrist),
            thresholds: PhaseThresholds(relaxed: 165.0, contracted: 85.0, hysteresis: 15.0),
            maxOccludedFrames: 8,
            primaryMuscles: ["upper-back", "lats"], secondaryMuscles: ["biceps", "lower-back", "deltoids"],
            texts: PhaseTexts(contracting: String(localized: "Pull down"), contracted: String(localized: "Squeeze back"), extending: String(localized: "Reach up"), relaxed: String(localized: "Stretch lats")))
    }

    private static func verticalPress(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .angle(.shoulder, .elbow, .wrist),
            thresholds: PhaseThresholds(relaxed: 60.0, contracted: 160.0, hysteresis: 15.0),
            maxOccludedFrames: 8,
            primaryMuscles: ["deltoids", "triceps"], secondaryMuscles: ["trapezius"],
            texts: PhaseTexts(contracting: "Press overhead!", contracted: "Locked out", extending: "Lower safely", relaxed: "Ready"))
    }

    private static func hingePattern(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .angle(.shoulder, .hip, .knee),
            thresholds: PhaseThresholds(relaxed: 170.0, contracted: 90.0, hysteresis: 15.0),
            maxOccludedFrames: 10,
            primaryMuscles: ["hamstring", "gluteal", "lower-back"], secondaryMuscles: ["trapezius", "forearm"],
            texts: PhaseTexts(contracting: "Hinge hips...", contracted: "Thrust hips!", extending: "Lock hips", relaxed: "Standing tall"))
    }

    private static func lungePattern(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .angle(.hip, .knee, .ankle),
            thresholds: PhaseThresholds(relaxed: 170.0, contracted: 90.0, hysteresis: 15.0),
            maxOccludedFrames: 10,
            primaryMuscles: ["quadriceps", "gluteal", "hamstring"], secondaryMuscles: ["calves"],
            texts: PhaseTexts(contracting: "Drop knee...", contracted: "Push through heel!", extending: "Rise up", relaxed: "Feet together"))
    }

    private static func tricepsExtension(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .angle(.shoulder, .elbow, .wrist),
            thresholds: PhaseThresholds(relaxed: 60.0, contracted: 165.0, hysteresis: 15.0),
            maxOccludedFrames: 8,
            primaryMuscles: ["triceps"], secondaryMuscles: ["deltoids"],
            texts: PhaseTexts(contracting: String(localized: "Extend arm"), contracted: String(localized: "Squeeze triceps"), extending: String(localized: "Bend arm"), relaxed: String(localized: "Stretch triceps")))
    }

    private static func coreFlexion(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .angle(.shoulder, .hip, .knee),
            thresholds: PhaseThresholds(relaxed: 170.0, contracted: 90.0, hysteresis: 15.0),
            maxOccludedFrames: 8,
            primaryMuscles: ["abs"], secondaryMuscles: ["obliques"],
            texts: PhaseTexts(contracting: String(localized: "Stand up"), contracted: String(localized: "Stand tall"), extending: String(localized: "Squat down"), relaxed: String(localized: "Hold bottom")))
    }

    private static func lateralRaise(name: String) -> BiomechanicsProfile {
        BiomechanicsProfile(exerciseName: name,
            metric: .angle(.hip, .shoulder, .elbow),
            thresholds: PhaseThresholds(relaxed: 15.0, contracted: 85.0, hysteresis: 10.0),
            maxOccludedFrames: 8,
            primaryMuscles: ["deltoids"], secondaryMuscles: ["trapezius", "upper-back"],
            texts: PhaseTexts(contracting: String(localized: "Curl up"), contracted: String(localized: "Squeeze biceps"), extending: String(localized: "Lower slowly"), relaxed: String(localized: "Arms straight")))
    }

    private static func calfRaise(name: String) -> BiomechanicsProfile {
        // ✅ normalizedDistance — нормализован по высоте торса
        BiomechanicsProfile(exerciseName: name,
            metric: .normalizedDistance(.knee, .ankle),
            thresholds: PhaseThresholds(relaxed: 1.1, contracted: 1.3, hysteresis: 0.05),
            maxOccludedFrames: 8,
            primaryMuscles: ["calves"], secondaryMuscles: [],
            texts: PhaseTexts(contracting: String(localized: "Up on toes!"), contracted: String(localized: "Peak contraction"), extending: String(localized: "Heels down"), relaxed: String(localized: "Heels flat")))
    }
}

// MARK: - Movement Phase & Tracking State

public enum MovementPhase: Sendable {
    case relaxed, contracting, contracted, extending, unknown
}

public struct TrackingState: Sendable {
    public var phase: MovementPhase = .unknown
    public var repsCount: Int = 0
    public var currentAmplitude: Double = 0.0

    public var concentricStartTime: Date? = nil
    public var concentricDurations: [TimeInterval] = []
    public var isVBTWarningTriggered: Bool = false

    fileprivate var missingFramesCount: Int = 0
    fileprivate var lastValidMetricValue: Double? = nil
    fileprivate var smoothedMetricValue: Double? = nil
}

// MARK: - RepetitionTracker

public final class RepetitionTracker {
    private let profile: BiomechanicsProfile
    private(set) var state: TrackingState

    // Adaptive EMA bounds
    private let emaAlphaMin: Double = 0.15  // медленное движение → больше сглаживания
    private let emaAlphaMax: Double = 0.80  // быстрое движение → быстрый отклик

    public init(profile: BiomechanicsProfile) {
        self.profile = profile
        self.state = TrackingState()
    }

    public func process(joints: [AgnosticJointName: CGPoint]) -> TrackingState {
        guard let rawMetricValue = extractMetricValue(profile.metric, from: joints) else {
            return handleOcclusion()
        }

        state.missingFramesCount = 0
        state.lastValidMetricValue = rawMetricValue

        // ✅ УЛУЧШЕНИЕ: Адаптивный EMA-alpha
        // При быстром движении (delta большой) → высокий alpha = быстрый отклик
        // При медленном движении (delta малый)  → низкий alpha = больше сглаживания
        let smoothed: Double
        if let prev = state.smoothedMetricValue {
            let alpha = adaptiveAlpha(current: rawMetricValue, previous: prev)
            smoothed = alpha * rawMetricValue + (1.0 - alpha) * prev
        } else {
            smoothed = rawMetricValue
        }
        state.smoothedMetricValue = smoothed

        state.currentAmplitude = BiomechanicsMath.amplitudePercentage(
            current: smoothed,
            relaxed: profile.thresholds.relaxed,
            contracted: profile.thresholds.contracted
        )

        updatePhase(with: smoothed)
        return state
    }

    // MARK: - Adaptive EMA

    /// Вычисляет EMA-alpha в зависимости от скорости движения (нормализованной к диапазону метрики).
    /// Это позволяет точно отслеживать и медленные (силовые) и быстрые (взрывные) движения.
    private func adaptiveAlpha(current: Double, previous: Double) -> Double {
        let totalRange = abs(profile.thresholds.contracted - profile.thresholds.relaxed)
        guard totalRange > 0 else { return 0.4 }

        // Скорость: какую долю от всего диапазона метрики прошли за 1 фрейм
        // При stride=2 и 30fps → каждые ~66мс
        // 0.15 * range = "нормальная" скорость → alpha ≈ 0.5
        let delta = abs(current - previous)
        let normalizedVelocity = min(1.0, delta / (totalRange * 0.15))

        return emaAlphaMin + normalizedVelocity * (emaAlphaMax - emaAlphaMin)
    }

    // MARK: - Occlusion

    private func handleOcclusion() -> TrackingState {
        state.missingFramesCount += 1
        if state.missingFramesCount > profile.maxOccludedFrames {
            state.phase = .unknown
            state.currentAmplitude = 0.0
            state.lastValidMetricValue = nil
            // smoothedMetricValue не сбрасываем — быстро восстановится
        }
        return state
    }

    // MARK: - Phase Machine

    private func updatePhase(with value: Double) {
        let t = profile.thresholds
        let isDecreasing = t.contracted < t.relaxed

        let reachedContracted = isDecreasing
            ? (value <= t.contracted + t.hysteresis)
            : (value >= t.contracted - t.hysteresis)
        let reachedRelaxed = isDecreasing
            ? (value >= t.relaxed - t.hysteresis)
            : (value <= t.relaxed + t.hysteresis)

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
            } else if reachedRelaxed {
                state.phase = .relaxed
            }
        case .contracted:
            if !reachedContracted { state.phase = .extending }
        case .extending:
            if reachedRelaxed {
                state.phase = .relaxed
                state.repsCount += 1
                print("💪 Rep \(state.repsCount) — метрика: \(String(format: "%.2f", value))")
            } else if reachedContracted {
                state.phase = .contracted
            }
        }
    }

    // MARK: - Metric Extraction (с поддержкой нормализации по торсу)

    private func extractMetricValue(
        _ metric: MovementMetric,
        from joints: [AgnosticJointName: CGPoint]
    ) -> Double? {
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

        // ✅ УЛУЧШЕНИЕ: Нормализованные метрики — значение в единицах торса
        case .normalizedDistance(let j1, let j2):
            guard let p1 = joints[j1], let p2 = joints[j2] else { return nil }
            let raw = BiomechanicsMath.distance(p1: p1, p2: p2)
            guard let torso = BiomechanicsMath.torsoHeight(joints: joints) else {
                return raw  // Fallback: без нормализации если торс не виден
            }
            return raw / torso

        case .normalizedProjectionY(let j1, let j2):
            guard let p1 = joints[j1], let p2 = joints[j2] else { return nil }
            let raw = BiomechanicsMath.projectedDistanceY(p1: p1, p2: p2)
            guard let torso = BiomechanicsMath.torsoHeight(joints: joints) else {
                return raw  // Fallback: без нормализации если торс не виден
            }
            return raw / torso

        case .fallback(let primary, let secondary):
            return extractMetricValue(primary, from: joints)
                ?? extractMetricValue(secondary, from: joints)
        }
    }
}

// MARK: - AITrackerEngine

@MainActor
public final class AITrackerEngine: ObservableObject {

    @Published public private(set) var repsCount: Int = 0
    @Published public private(set) var feedbackMessage: String = String(localized: "Initializing AI...")
    @Published public private(set) var isTrackingAction: Bool = false
    @Published public var liveMuscleTension: [String: Int] = [:]
    @Published public private(set) var vbtWarningTriggered: Bool = false

    private let exerciseName: String
    private var profile: BiomechanicsProfile?
    private let mlEngine = MLWorkoutEngine()
    private var repetitionTracker: RepetitionTracker?

    // ✅ УЛУЧШЕНИЕ: SideSelector — стабильный per-frame выбор лучшей стороны тела
    private let sideSelector = SideSelector()

    private var cancellables = Set<AnyCancellable>()

    public init(exerciseName: String) {
        self.exerciseName = exerciseName
        setupMLSubscription()
    }

    public func setup() async {
        let pattern = await ExerciseDatabaseService.shared.getPattern(for: exerciseName)
        self.profile = ExerciseRegistry.profile(for: pattern, exerciseName: exerciseName)

        if let profile = self.profile {
            self.repetitionTracker = RepetitionTracker(profile: profile)
            self.feedbackMessage = String(localized: "Ready. Waiting for action.")
            print("🤖 AITrackerEngine: \(profile.exerciseName) — паттерн: \(pattern)")
        } else {
            self.feedbackMessage = String(localized: "AI Tracking not supported for this exercise.")
            print("⚠️ AITrackerEngine: Профиль не найден для '\(exerciseName)'")
        }
    }

    private func setupMLSubscription() {
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
                liveMuscleTension.removeAll()
            }
        }
    }

    public func processFrame(observation: VNHumanBodyPoseObservation) {
        guard let tracker = repetitionTracker, let profile = self.profile else { return }

        mlEngine.processFrame(observation: observation)

        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }

        // ✅ УЛУЧШЕНИЕ: Обновляем SideSelector каждый фрейм — плавный выбор стороны с гистерезисом
        sideSelector.update(points: recognizedPoints)

        // Извлекаем агностические суставы с учётом текущего выбора стороны
        let agnosticJoints = BiomechanicsMath.extractAgnosticJoints(
            from: recognizedPoints,
            preferLeft: sideSelector.preferLeft
        )

        let state = tracker.process(joints: agnosticJoints)
        syncStateToUI(state: state, profile: profile)
    }

    private func syncStateToUI(state: TrackingState, profile: BiomechanicsProfile) {
        if self.repsCount != state.repsCount {
            self.repsCount = state.repsCount
        }

        if state.isVBTWarningTriggered && !self.vbtWarningTriggered {
            self.vbtWarningTriggered = true
        }

        let tension = Int(state.currentAmplitude)
        var newTension: [String: Int] = [:]

        if tension > 0 {
            for m in profile.primaryMuscles   { newTension[m] = tension }
            for m in profile.secondaryMuscles { newTension[m] = tension / 2 }
        }
        self.liveMuscleTension = newTension

        let newFeedback: String
        switch state.phase {
        case .relaxed:     newFeedback = profile.texts.relaxed
        case .contracting: newFeedback = profile.texts.contracting
        case .contracted:  newFeedback = profile.texts.contracted
        case .extending:   newFeedback = profile.texts.extending
        case .unknown:     newFeedback = String(localized: "Body parts occluded. Adjust camera!")
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
            self.feedbackMessage = String(localized: "Ready. Waiting for action.")
        }
    }
}

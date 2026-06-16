

internal import SwiftUI
import Vision
import CoreGraphics
import Combine
import AVFoundation

// MARK: - Types

enum RecognizedGesture: Equatable {
    case none
    case victory    // ✌️ — засчитать сет
    case openPalm   // 🖐 — отменить сет
}

enum GestureAction {
    case confirmSet
    case cancelSet
}

// MARK: - GestureController

@MainActor
final class GestureController: ObservableObject {

    // UI-observable state
    @Published var activeGesture: RecognizedGesture = .none
    @Published var gestureProgress: Double = 0.0

    /// Subscribe to get gesture events — каждый раз срабатывает при новом жесте
    let gestureAction = PassthroughSubject<GestureAction, Never>()

    // Internal tracking
    private var currentTrackingGesture: RecognizedGesture = .none
    private var gestureStartTime: Date?
    private var cooldownUntil: Date = .distantPast

    // Tuning constants
    private let dwellTimeRequired: TimeInterval = 3.0   // Увеличено для защиты от случайных срабатываний
    private let confidenceThreshold: Float = 0.35       // Было 0.5 — снижено
    private let cooldownDuration: TimeInterval = 3.0    // Кулдаун после триггера

    // MARK: - Public API

    nonisolated func processHandPose(observation: VNHumanHandPoseObservation) {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            Task { @MainActor in self.updateGestureState(detected: .none) }
            return
        }
        let detectedGesture = detectGesture(from: recognizedPoints)

        Task { @MainActor in
            self.updateGestureState(detected: detectedGesture)
        }
    }

    // MARK: - State Machine

    @MainActor
    private func updateGestureState(detected: RecognizedGesture) {
        // Не принимать жесты во время кулдауна
        let now = Date()
        guard now >= cooldownUntil else {
            // Сбросить UI но не менять трекинг
            if activeGesture != .none {
                activeGesture = .none
                withAnimation(.easeOut(duration: 0.2)) { gestureProgress = 0.0 }
            }
            return
        }

        if detected == currentTrackingGesture && detected != .none {
            // Продолжаем удерживать жест — накапливаем прогресс
            guard let startTime = gestureStartTime else {
                gestureStartTime = now
                return
            }
            let elapsed = now.timeIntervalSince(startTime)
            let rawProgress = elapsed / dwellTimeRequired

            withAnimation(.linear(duration: 0.08)) {
                gestureProgress = min(1.0, rawProgress)
            }

            if gestureProgress >= 1.0 {
                triggerAction(for: detected)
            }

        } else {
            // Жест изменился или пропал — сброс
            currentTrackingGesture = detected
            activeGesture = detected
            gestureStartTime = (detected == .none) ? nil : now

            withAnimation(.easeOut(duration: 0.2)) {
                gestureProgress = 0.0
            }

            if detected != .none {
                print("🤚 GestureController: Начал удерживать жест \(detected)")
            }
        }
    }

    @MainActor
    private func triggerAction(for gesture: RecognizedGesture) {
        print("✅ GestureController: Триггер жеста \(gesture)")

        let generator = UINotificationFeedbackGenerator()

        switch gesture {
        case .victory:
            print("🎯 GestureController: Отправка события confirmSet")
            generator.notificationOccurred(.success)
            gestureAction.send(.confirmSet)

        case .openPalm:
            print("🎯 GestureController: Отправка события cancelSet")
            generator.notificationOccurred(.error)
            gestureAction.send(.cancelSet)

        case .none:
            break
        }

        // Сбросить состояние
        gestureProgress = 0.0
        gestureStartTime = nil
        currentTrackingGesture = .none
        activeGesture = .none

        // Включить кулдаун
        cooldownUntil = Date().addingTimeInterval(cooldownDuration)
    }

    // MARK: - Gesture Detection

    /// Основной алгоритм распознавания жестов.
    /// Нормализует расстояния относительно размера ладони — устойчиво к расстоянию от камеры.
    nonisolated private func detectGesture(
        from points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]
    ) -> RecognizedGesture {

        guard let wrist = getValidPoint(points, .wrist),
              let middleMCP = getValidPoint(points, .middleMCP) else {
            return .none
        }

        // Размер ладони — опорное расстояние для нормализации
        let palmSize = wrist.distance(to: middleMCP)
        guard palmSize > 0.01 else { return .none }

        // Проверяем каждый палец через нормализованное расстояние
        let isIndexExt  = isFingerExtended(points, tip: .indexTip,  pip: .indexPIP,  mcp: .indexMCP,  wrist: wrist, palm: palmSize)
        let isMiddleExt = isFingerExtended(points, tip: .middleTip, pip: .middlePIP, mcp: .middleMCP, wrist: wrist, palm: palmSize)
        let isRingExt   = isFingerExtended(points, tip: .ringTip,   pip: .ringPIP,   mcp: .ringMCP,   wrist: wrist, palm: palmSize)
        let isLittleExt = isFingerExtended(points, tip: .littleTip, pip: .littlePIP, mcp: .littleMCP, wrist: wrist, palm: palmSize)
        let isThumbExt  = isThumbExtended(points, wrist: wrist, palm: palmSize)

        // ✌️ Victory: указательный + средний вытянуты, остальные согнуты, большой может быть любым
        let isVictory = isIndexExt && isMiddleExt && !isRingExt && !isLittleExt

        // 🖐 Open Palm: все 4 пальца + большой вытянуты
        let isOpenPalm = isIndexExt && isMiddleExt && isRingExt && isLittleExt && isThumbExt

        if isOpenPalm {
            return .openPalm
        }

        if isVictory {
            return .victory
        }

        return .none
    }

    /// Проверяет, вытянут ли палец — нормализует по размеру ладони.
    nonisolated private func isFingerExtended(
        _ points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
        tip: VNHumanHandPoseObservation.JointName,
        pip: VNHumanHandPoseObservation.JointName,
        mcp: VNHumanHandPoseObservation.JointName,
        wrist: CGPoint,
        palm: CGFloat
    ) -> Bool {
        guard let tipPt = getValidPoint(points, tip),
              let pipPt = getValidPoint(points, pip) else { return false }

        // Нормализованные расстояния от запястья
        let tipDist = tipPt.distance(to: wrist) / palm
        let pipDist = pipPt.distance(to: wrist) / palm

        // Кончик пальца должен быть значительно дальше PIP-сустава
        return tipDist > pipDist * 1.1
    }

    /// Специальная проверка для большого пальца (другая геометрия)
    nonisolated private func isThumbExtended(
        _ points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
        wrist: CGPoint,
        palm: CGFloat
    ) -> Bool {
        guard let tipPt  = getValidPoint(points, .thumbTip),
              let ipPt   = getValidPoint(points, .thumbIP),
              let mcpPt  = getValidPoint(points, .thumbMP) else { return false }

        let tipDist = tipPt.distance(to: wrist) / palm
        let ipDist  = ipPt.distance(to: wrist) / palm
        let mcpDist = mcpPt.distance(to: wrist) / palm

        // Большой вытянут если кончик дальше IP и MCP суставов
        return tipDist > ipDist && tipDist > mcpDist * 1.05
    }

    nonisolated private func getValidPoint(
        _ points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
        _ name: VNHumanHandPoseObservation.JointName
    ) -> CGPoint? {
        guard let point = points[name], point.confidence > confidenceThreshold else { return nil }
        return point.location
    }
}

// MARK: - CGPoint extension

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return hypot(self.x - point.x, self.y - point.y)
    }
}

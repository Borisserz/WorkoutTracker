//
//  AITrackerEngine.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 25.03.26.
//

import Foundation
import Vision
import CoreGraphics
import Combine
import UIKit

// MARK: - Enums

enum TrackedExercise: String {
    case squat
    case pushUp
    case deadlift
    case lunge
    case bicepCurl
    case unsupported
    
    init(name: String) {
        let lowercased = name.lowercased()
        if lowercased.contains("squat") {
            self = .squat
        } else if lowercased.contains("push up") || lowercased.contains("push-up") {
            self = .pushUp
        } else if lowercased.contains("deadlift") {
            self = .deadlift
        } else if lowercased.contains("lunge") {
            self = .lunge
        } else if lowercased.contains("curl") {
            self = .bicepCurl
        } else {
            self = .unsupported
        }
    }
    
    func matches(mlAction: String) -> Bool {
        let lower = mlAction.lowercased()
        switch self {
        case .squat: return lower.contains("squat")
        case .pushUp: return lower.contains("push")
        case .deadlift: return lower.contains("deadlift")
        case .lunge: return lower.contains("lunge")
        case .bicepCurl: return lower.contains("curl")
        case .unsupported: return false
        }
    }
}

// MARK: - Biomechanics Math & Helpers

struct ActiveJoints {
    let neck: CGPoint?
    let shoulder: CGPoint?
    let elbow: CGPoint?
    let wrist: CGPoint?
    let hip: CGPoint?
    let knee: CGPoint?
    let ankle: CGPoint?
}

struct BiomechanicsMath {
    
    /// Рассчитывает внутренний угол между тремя точками (в градусах).
    static func angleBetween(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: p1.x - p2.x, y: p1.y - p2.y)
        let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        
        let dotProduct = (v1.x * v2.x) + (v1.y * v2.y)
        let magnitude1 = hypot(v1.x, v1.y)
        let magnitude2 = hypot(v2.x, v2.y)
        
        guard magnitude1 > 0, magnitude2 > 0 else { return 0.0 }
        
        let cosineAngle = dotProduct / (magnitude1 * magnitude2)
        
        // Защита от NaN при ошибках округления float
        let clampedCosine = max(-1.0, min(1.0, cosineAngle))
        let angleInRadians = acos(clampedCosine)
        
        return angleInRadians * (180.0 / .pi)
    }
    
    /// Умный экстрактор рабочей стороны.
    static func extractActiveSide(joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> ActiveJoints {
        let leftJoints: [VNHumanBodyPoseObservation.JointName] = [.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle]
        let rightJoints: [VNHumanBodyPoseObservation.JointName] = [.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle]
        
        let leftScore = leftJoints.compactMap { joints[$0] }.count
        let rightScore = rightJoints.compactMap { joints[$0] }.count
        
        let isLeft = leftScore >= rightScore
        
        return ActiveJoints(
            neck: joints[.neck] ?? joints[.nose], // Фолбэк на нос, если шея перекрыта
            shoulder: isLeft ? joints[.leftShoulder] : joints[.rightShoulder],
            elbow: isLeft ? joints[.leftElbow] : joints[.rightElbow],
            wrist: isLeft ? joints[.leftWrist] : joints[.rightWrist],
            hip: isLeft ? joints[.leftHip] : joints[.rightHip],
            knee: isLeft ? joints[.leftKnee] : joints[.rightKnee],
            ankle: isLeft ? joints[.leftAnkle] : joints[.rightAnkle]
        )
    }
}

// MARK: - Hybrid AI Tracker Engine

@MainActor
final class AITrackerEngine: ObservableObject {
    
    // MARK: - Published State (UI)
    
    @Published private(set) var repsCount: Int = 0
    @Published private(set) var feedbackMessage: String = "Ready"
    @Published private(set) var isTrackingAction: Bool = false
    
    // Живое напряжение мышц (Live Muscle Activation) от 0 до 100%
    @Published var liveMuscleTension: [String: Int] = [:]
    
    // MARK: - Internal State
    
    private let exercise: TrackedExercise
    private let mlEngine = MLWorkoutEngine()
    private var cancellables = Set<AnyCancellable>()
    
    // Внутренний флаг для стейт-машины Core ML классификатора
    private var isMLActivePhase = false
    
    // MARK: - Init
    
    init(exerciseName: String) {
        self.exercise = TrackedExercise(name: exerciseName)
        
        if self.exercise == .unsupported {
            self.feedbackMessage = "Exercise not supported by AI"
        }
        
        setupMLSubscription()
    }
    
    // MARK: - ML Rep Counting (Combine State Machine)
    
    private func setupMLSubscription() {
        // Подписываемся на изменение текущего действия от Core ML
        mlEngine.$currentAction
            .dropFirst()
            .sink { [weak self] action in
                self?.handleMLActionChange(action)
            }
            .store(in: &cancellables)
    }
    
    private func handleMLActionChange(_ action: String) {
        guard exercise != .unsupported else { return }
        
        let isCurrentExerciseAction = exercise.matches(mlAction: action)
        
        if isCurrentExerciseAction {
            // Начали делать упражнение (концентрическая фаза)
            if !isMLActivePhase {
                isMLActivePhase = true
                updateTrackingState(true)
            }
        } else {
            // Перестали делать упражнение (перешли в Idle или сменили позу)
            if isMLActivePhase {
                isMLActivePhase = false
                updateTrackingState(false)
                
                // Засчитываем повторение
                repsCount += 1
                updateFeedback("Great rep!")
                triggerHaptic()
            }
        }
    }
    
    private func triggerHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - Public API
    
    func processFrame(observation: VNHumanBodyPoseObservation) {
        guard exercise != .unsupported else { return }
        
        // 1. Отдаем сырой кадр в Core ML для анализа и подсчета повторений
        mlEngine.processFrame(observation: observation)
        
        // 2. Извлекаем точки для эвристической математики (Форма и Напряжение мышц)
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        
        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for (key, point) in recognizedPoints where point.confidence > 0.3 {
            // Инверсия Y оси (Vision vs UIKit/SwiftUI)
            joints[key] = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
        }
        
        let activeSide = BiomechanicsMath.extractActiveSide(joints: joints)
        
        // 3. Запускаем математику для отрисовки напряжения мышц и советов по осанке
        switch exercise {
        case .squat:
            processSquat(side: activeSide)
        case .pushUp:
            processPushUp(side: activeSide)
        case .deadlift:
            processDeadlift(side: activeSide)
        case .lunge:
            processLunge(side: activeSide)
        case .bicepCurl:
            processBicepCurl(side: activeSide)
        case .unsupported:
            break
        }
    }
    
    func reset() {
        repsCount = 0
        isMLActivePhase = false
        updateFeedback("Ready")
        updateTrackingState(false)
        liveMuscleTension.removeAll()
        mlEngine.reset()
    }
    
    // MARK: - Biomechanics Math & Helpers
    
    /// Helper для перевода угла сустава в процент напряжения
    private func calculateTension(currentAngle: CGFloat, relaxedAngle: CGFloat, contractedAngle: CGFloat) -> Int {
        let range = relaxedAngle - contractedAngle
        guard range != 0 else { return 0 }
        
        let progress = (relaxedAngle - currentAngle) / range
        let percentage = Int(progress * 100)
        
        return max(0, min(100, percentage))
    }
    
    // MARK: - Exercise Processors (Form & Tension ONLY)
    
    private func processSquat(side: ActiveJoints) {
        guard let hip = side.hip, let knee = side.knee, let ankle = side.ankle, let neck = side.neck else {
            liveMuscleTension.removeAll()
            return
        }
        
        let kneeAngle = BiomechanicsMath.angleBetween(p1: hip, p2: knee, p3: ankle)
        
        // Считаем напряжение ног (квадрицепсы и ягодичные)
        let tension = calculateTension(currentAngle: kneeAngle, relaxedAngle: 160.0, contractedAngle: 90.0)
        liveMuscleTension["quadriceps"] = tension
        liveMuscleTension["gluteal"] = tension
        
        let verticalRef = CGPoint(x: hip.x, y: hip.y - 0.1)
        let backLeanAngle = BiomechanicsMath.angleBetween(p1: neck, p2: hip, p3: verticalRef)
        
        if isMLActivePhase {
            if backLeanAngle > 45.0 {
                updateFeedback("Keep your back straight!")
            } else if kneeAngle < 90.0 {
                updateFeedback("Good depth! Push up!")
            } else {
                updateFeedback("Lower...")
            }
        } else {
            if feedbackMessage != "Great rep!" {
                updateFeedback("Ready")
            }
        }
    }
    
    private func processPushUp(side: ActiveJoints) {
        guard let shoulder = side.shoulder, let elbow = side.elbow, let wrist = side.wrist,
              let hip = side.hip, let ankle = side.ankle else {
            liveMuscleTension.removeAll()
            return
        }
        
        let elbowAngle = BiomechanicsMath.angleBetween(p1: shoulder, p2: elbow, p3: wrist)
        let bodyAngle = BiomechanicsMath.angleBetween(p1: shoulder, p2: hip, p3: ankle)
        
        // Грудь и трицепс
        let tension = calculateTension(currentAngle: elbowAngle, relaxedAngle: 160.0, contractedAngle: 90.0)
        liveMuscleTension["chest"] = tension
        liveMuscleTension["triceps"] = tension
        liveMuscleTension["deltoids"] = tension / 2 // Дельты тоже работают, но меньше
        
        if bodyAngle < 150.0 {
            updateFeedback("Keep your body straight!")
        } else if isMLActivePhase {
            if elbowAngle < 90.0 {
                updateFeedback("Push up!")
            } else {
                updateFeedback("Lower...")
            }
        } else if feedbackMessage != "Great rep!" {
            updateFeedback("Ready")
        }
    }
    
    private func processDeadlift(side: ActiveJoints) {
        guard let shoulder = side.shoulder, let hip = side.hip, let knee = side.knee, let neck = side.neck else {
            liveMuscleTension.removeAll()
            return
        }
        
        let hipAngle = BiomechanicsMath.angleBetween(p1: shoulder, p2: hip, p3: knee)
        
        // Спина и бицепс бедра
        let tension = calculateTension(currentAngle: hipAngle, relaxedAngle: 170.0, contractedAngle: 90.0)
        liveMuscleTension["hamstring"] = tension
        liveMuscleTension["lower-back"] = tension
        liveMuscleTension["gluteal"] = tension
        
        let verticalRef = CGPoint(x: hip.x, y: hip.y - 0.1)
        let backLeanAngle = BiomechanicsMath.angleBetween(p1: neck, p2: hip, p3: verticalRef)
        
        if backLeanAngle > 85.0 {
            updateFeedback("Don't round your back!")
        } else if isMLActivePhase {
            if hipAngle < 100.0 {
                updateFeedback("Good hinge. Squeeze glutes!")
            } else {
                updateFeedback("Hinge forward...")
            }
        } else if feedbackMessage != "Great rep!" {
            updateFeedback("Ready")
        }
    }
    
    private func processLunge(side: ActiveJoints) {
        guard let hip = side.hip, let knee = side.knee, let ankle = side.ankle else {
            liveMuscleTension.removeAll()
            return
        }
        
        let kneeAngle = BiomechanicsMath.angleBetween(p1: hip, p2: knee, p3: ankle)
        
        // Ноги
        let tension = calculateTension(currentAngle: kneeAngle, relaxedAngle: 160.0, contractedAngle: 90.0)
        liveMuscleTension["quadriceps"] = tension
        liveMuscleTension["gluteal"] = tension
        liveMuscleTension["calves"] = tension / 2
        
        if isMLActivePhase {
            if kneeAngle < 90.0 {
                updateFeedback("Push back up!")
            } else {
                updateFeedback("Lower...")
            }
        } else if feedbackMessage != "Great rep!" {
            updateFeedback("Ready")
        }
    }
    
    private func processBicepCurl(side: ActiveJoints) {
        guard let shoulder = side.shoulder, let elbow = side.elbow, let wrist = side.wrist,
              let hip = side.hip, let neck = side.neck else {
            liveMuscleTension.removeAll()
            return
        }
        
        let elbowAngle = BiomechanicsMath.angleBetween(p1: shoulder, p2: elbow, p3: wrist)
        
        // Считаем напряжение бицепса
        let tension = calculateTension(currentAngle: elbowAngle, relaxedAngle: 160.0, contractedAngle: 60.0)
        liveMuscleTension["biceps"] = tension
        
        let verticalRef = CGPoint(x: hip.x, y: hip.y - 0.1)
        let backLeanAngle = BiomechanicsMath.angleBetween(p1: neck, p2: hip, p3: verticalRef)
        
        if backLeanAngle > 20.0 {
            updateFeedback("Don't swing your back!")
        } else if isMLActivePhase {
            if elbowAngle < 60.0 {
                updateFeedback("Squeeze and lower slowly")
            } else if elbowAngle > 100.0 {
                updateFeedback("Lower all the way")
            } else {
                updateFeedback("Curl up...")
            }
        } else if feedbackMessage != "Great rep!" {
            updateFeedback("Ready")
        }
    }
    
    // MARK: - State Update Helpers
    
    private func updateFeedback(_ text: String) {
        if feedbackMessage != text {
            feedbackMessage = text
        }
    }
    
    private func updateTrackingState(_ state: Bool) {
        if isTrackingAction != state {
            isTrackingAction = state
        }
    }
}

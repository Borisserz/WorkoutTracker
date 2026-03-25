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

// MARK: - Enums

enum TrackedExercise {
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
}

private enum ExercisePhase {
    case start   // Исходное положение (эксцентрическая фаза / выпрямлен)
    case middle  // Пик амплитуды (концентрическая фаза / согнут)
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
    /// - Parameters:
    ///   - p1: Первая точка
    ///   - p2: Центральная точка (вершина угла)
    ///   - p3: Третья точка
    /// - Returns: Угол в диапазоне от 0.0 до 180.0 градусов.
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
    
    /// Умный экстрактор рабочей стороны. Анализирует количество доступных точек
    /// и возвращает суставы той стороны (левой или правой), которая лучше видна камере.
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

// MARK: - AI Tracker Engine

@MainActor
final class AITrackerEngine: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var repsCount: Int = 0
    @Published private(set) var feedbackMessage: String = "Ready"
    @Published private(set) var isTrackingAction: Bool = false
    
    // MARK: - Internal State
    
    private let exercise: TrackedExercise
    private var currentPhase: ExercisePhase = .start
    
    // MARK: - Init
    
    init(exerciseName: String) {
        self.exercise = TrackedExercise(name: exerciseName)
        
        if self.exercise == .unsupported {
            self.feedbackMessage = "Exercise not supported by AI"
        }
    }
    
    // MARK: - Public API
    
    func processFrame(joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        guard exercise != .unsupported else { return }
        
        let activeSide = BiomechanicsMath.extractActiveSide(joints: joints)
        
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
        currentPhase = .start
        updateFeedback("Ready")
        updateTrackingState(false)
    }
    
    // MARK: - Exercise Processors
    
    private func processSquat(side: ActiveJoints) {
        guard let hip = side.hip, let knee = side.knee, let ankle = side.ankle, let neck = side.neck else {
            updateFeedback("Position body in frame")
            updateTrackingState(false)
            return
        }
        
        let kneeAngle = BiomechanicsMath.angleBetween(p1: hip, p2: knee, p3: ankle)
        updateTrackingState(kneeAngle < 140.0)
        
        switch currentPhase {
        case .start:
            if kneeAngle < 90.0 {
                currentPhase = .middle
                
                // Проверка осанки в нижней точке (угол шея-таз-вертикаль)
                let verticalRef = CGPoint(x: hip.x, y: hip.y - 0.1) // Координаты Vision: y=0 сверху
                let backLeanAngle = BiomechanicsMath.angleBetween(p1: neck, p2: hip, p3: verticalRef)
                
                if backLeanAngle > 45.0 {
                    updateFeedback("Keep your back straight!")
                } else {
                    updateFeedback("Good depth! Push up!")
                }
            } else if isTrackingAction {
                updateFeedback("Lower...")
            } else {
                updateFeedback("Ready")
            }
            
        case .middle:
            if kneeAngle > 150.0 {
                currentPhase = .start
                repsCount += 1
                updateFeedback("Great rep!")
            }
        }
    }
    
    private func processPushUp(side: ActiveJoints) {
        guard let shoulder = side.shoulder, let elbow = side.elbow, let wrist = side.wrist,
              let hip = side.hip, let ankle = side.ankle else {
            updateFeedback("Position body in frame")
            updateTrackingState(false)
            return
        }
        
        let elbowAngle = BiomechanicsMath.angleBetween(p1: shoulder, p2: elbow, p3: wrist)
        let bodyAngle = BiomechanicsMath.angleBetween(p1: shoulder, p2: hip, p3: ankle)
        
        updateTrackingState(elbowAngle < 150.0)
        
        // Постоянный контроль ровной спины/корпуса
        if bodyAngle < 150.0 {
            updateFeedback("Keep your body straight!")
            return // Блокируем прогресс фаз, если техника ужасна
        }
        
        switch currentPhase {
        case .start:
            if elbowAngle < 90.0 {
                currentPhase = .middle
                updateFeedback("Push up!")
            } else if isTrackingAction {
                updateFeedback("Lower...")
            } else {
                updateFeedback("Ready")
            }
            
        case .middle:
            if elbowAngle > 160.0 {
                currentPhase = .start
                repsCount += 1
                updateFeedback("Great rep!")
            }
        }
    }
    
    private func processDeadlift(side: ActiveJoints) {
        guard let shoulder = side.shoulder, let hip = side.hip, let knee = side.knee, let neck = side.neck else {
            updateFeedback("Position body in frame")
            updateTrackingState(false)
            return
        }
        
        let hipAngle = BiomechanicsMath.angleBetween(p1: shoulder, p2: hip, p3: knee)
        updateTrackingState(hipAngle < 150.0)
        
        switch currentPhase {
        case .start: // Фаза стояния
            if hipAngle < 100.0 {
                currentPhase = .middle // Фаза наклона (Hinge)
                
                let verticalRef = CGPoint(x: hip.x, y: hip.y - 0.1)
                let backLeanAngle = BiomechanicsMath.angleBetween(p1: neck, p2: hip, p3: verticalRef)
                
                if backLeanAngle > 85.0 {
                    updateFeedback("Don't round your back!")
                } else {
                    updateFeedback("Good hinge. Squeeze glutes!")
                }
            } else if isTrackingAction {
                updateFeedback("Hinge forward...")
            } else {
                updateFeedback("Ready")
            }
            
        case .middle:
            if hipAngle > 160.0 {
                currentPhase = .start
                repsCount += 1
                updateFeedback("Great rep!")
            }
        }
    }
    
    private func processLunge(side: ActiveJoints) {
        guard let hip = side.hip, let knee = side.knee, let ankle = side.ankle else {
            updateFeedback("Position body in frame")
            updateTrackingState(false)
            return
        }
        
        let kneeAngle = BiomechanicsMath.angleBetween(p1: hip, p2: knee, p3: ankle)
        updateTrackingState(kneeAngle < 150.0)
        
        switch currentPhase {
        case .start:
            if kneeAngle < 90.0 {
                currentPhase = .middle
                updateFeedback("Push back up!")
            } else if isTrackingAction {
                updateFeedback("Lower...")
            } else {
                updateFeedback("Ready")
            }
            
        case .middle:
            if kneeAngle > 150.0 {
                currentPhase = .start
                repsCount += 1
                updateFeedback("Great rep!")
            }
        }
    }
    
    private func processBicepCurl(side: ActiveJoints) {
        guard let shoulder = side.shoulder, let elbow = side.elbow, let wrist = side.wrist,
              let hip = side.hip, let neck = side.neck else {
            updateFeedback("Position body in frame")
            updateTrackingState(false)
            return
        }
        
        let elbowAngle = BiomechanicsMath.angleBetween(p1: shoulder, p2: elbow, p3: wrist)
        updateTrackingState(elbowAngle < 140.0)
        
        switch currentPhase {
        case .start: // Руки опущены
            if elbowAngle < 60.0 {
                currentPhase = .middle // Пик сокращения бицепса
                
                // Контроль читинга (раскачки спиной)
                let verticalRef = CGPoint(x: hip.x, y: hip.y - 0.1)
                let backLeanAngle = BiomechanicsMath.angleBetween(p1: neck, p2: hip, p3: verticalRef)
                
                if backLeanAngle > 20.0 {
                    updateFeedback("Don't swing your back!")
                } else {
                    updateFeedback("Squeeze and lower slowly")
                }
            } else if isTrackingAction {
                updateFeedback("Curl up...")
            } else {
                updateFeedback("Ready")
            }
            
        case .middle:
            // Возврат в начальную фазу с полным растяжением
            if elbowAngle > 150.0 {
                currentPhase = .start
                repsCount += 1
                updateFeedback("Great rep!")
            } else if elbowAngle > 100.0 {
                updateFeedback("Lower all the way")
            }
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

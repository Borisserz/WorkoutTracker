//
//  GestureController.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.03.26.
//

internal import SwiftUI
import Vision
import CoreGraphics
import Combine 
import AVFoundation

enum RecognizedGesture {
    case none
    case victory
    case openPalm
}

@MainActor
final class GestureController: ObservableObject {
    
    @Published var activeGesture: RecognizedGesture = .none
    @Published var gestureProgress: Double = 0.0
    @Published var didConfirmSet: Bool = false
    @Published var didCancelSet: Bool = false
    
    private var currentTrackingGesture: RecognizedGesture = .none
    private var gestureStartTime: Date?
    private let dwellTimeRequired: TimeInterval = 1.0
    private let confidenceThreshold: Float = 0.5
    
    /// Анализирует кадр из Vision (Вызывается из фонового потока камеры)
    /// Nonisolated позволяет вызывать метод из фона, а внутренняя таска прыгнет на MainActor
    nonisolated func processHandPose(observation: VNHumanHandPoseObservation) {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        let detectedGesture = detectGesture(from: recognizedPoints)
        
        Task { @MainActor in
            self.updateGestureState(detected: detectedGesture)
        }
    }
    
    // MARK: - Dwell Time Logic (MainActor)
    
    @MainActor
    private func updateGestureState(detected: RecognizedGesture) {
        // Если жест совпадает с текущим и это не .none
        if detected == currentTrackingGesture && detected != .none {
            if let startTime = gestureStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                let rawProgress = elapsed / dwellTimeRequired
                
                // Плавно заполняем прогресс бар
                withAnimation(.linear(duration: 0.1)) {
                    gestureProgress = min(1.0, rawProgress)
                }
                
                // Триггер по достижению Dwell Time
                if gestureProgress >= 1.0 {
                    triggerAction(for: detected)
                }
            } else {
                gestureStartTime = Date()
            }
        } else {
            // Жест сменился или пропал — сбрасываем состояние
            currentTrackingGesture = detected
            activeGesture = detected
            gestureStartTime = detected == .none ? nil : Date()
            
            withAnimation(.easeOut(duration: 0.2)) {
                gestureProgress = 0.0
            }
        }
    }
    
    @MainActor
    private func triggerAction(for gesture: RecognizedGesture) {
        let generator = UINotificationFeedbackGenerator()
        
        if gesture == .victory{
            didConfirmSet = true
            generator.notificationOccurred(.success)
        } else if gesture == .openPalm {
            didCancelSet = true
            generator.notificationOccurred(.error)
        }
        
        // Сброс после триггера, чтобы не спамить экшены
        gestureProgress = 0.0
        gestureStartTime = nil
        currentTrackingGesture = .none
        activeGesture = .none
    }
    
    // MARK: - Heuristics & Math
    
    /// Математическое определение жеста
    nonisolated private func detectGesture(from points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]) -> RecognizedGesture {
            guard let wrist = getValidPoint(points, .wrist) else { return .none }
            
            func isFingerExtended(tip: VNHumanHandPoseObservation.JointName, pip: VNHumanHandPoseObservation.JointName) -> Bool {
                guard let tipPt = getValidPoint(points, tip),
                      let pipPt = getValidPoint(points, pip) else { return false }
                return tipPt.distance(to: wrist) > pipPt.distance(to: wrist)
            }
            
            let isIndexExt = isFingerExtended(tip: .indexTip, pip: .indexPIP)
            let isMiddleExt = isFingerExtended(tip: .middleTip, pip: .middlePIP)
            let isRingExt = isFingerExtended(tip: .ringTip, pip: .ringPIP)
            let isLittleExt = isFingerExtended(tip: .littleTip, pip: .littlePIP)
            
            let allFingersExtended = isIndexExt && isMiddleExt && isRingExt && isLittleExt
            
            // 1. ПРОВЕРКА НА VICTORY (✌️)
            // Указательный и средний вытянуты, безымянный и мизинец загнуты.
            // (Большой палец игнорируем, так как люди складывают его по-разному).
            if isIndexExt && isMiddleExt && !isRingExt && !isLittleExt {
                return .victory
            }
            
            // 2. ПРОВЕРКА НА OPEN PALM (✋)
            if allFingersExtended {
                return .openPalm
            }
            
            return .none
        }
    
    nonisolated private func getValidPoint(_ points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint], _ name: VNHumanHandPoseObservation.JointName) -> CGPoint? {
           guard let point = points[name], point.confidence > confidenceThreshold else { return nil }
           return point.location
       }
   }
// MARK: - Math Extension

extension CGPoint {
    /// Евклидово расстояние между двумя точками
    func distance(to point: CGPoint) -> CGFloat {
        return hypot(self.x - point.x, self.y - point.y)
    }
}



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

    nonisolated func processHandPose(observation: VNHumanHandPoseObservation) {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        let detectedGesture = detectGesture(from: recognizedPoints)

        Task { @MainActor in
            self.updateGestureState(detected: detectedGesture)
        }
    }

    @MainActor
    private func updateGestureState(detected: RecognizedGesture) {

        if detected == currentTrackingGesture && detected != .none {
            if let startTime = gestureStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                let rawProgress = elapsed / dwellTimeRequired

                withAnimation(.linear(duration: 0.1)) {
                    gestureProgress = min(1.0, rawProgress)
                }

                if gestureProgress >= 1.0 {
                    triggerAction(for: detected)
                }
            } else {
                gestureStartTime = Date()
            }
        } else {

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

        gestureProgress = 0.0
        gestureStartTime = nil
        currentTrackingGesture = .none
        activeGesture = .none
    }

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

            if isIndexExt && isMiddleExt && !isRingExt && !isLittleExt {
                return .victory
            }

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

extension CGPoint {

    func distance(to point: CGPoint) -> CGFloat {
        return hypot(self.x - point.x, self.y - point.y)
    }
}



import Foundation
internal import SwiftUI
import AVFoundation
import Vision
import Observation

@MainActor
@Observable
final class SmartCaptureViewModel: NSObject {

    var isAuthorized: Bool = false
    var countdown: Int? = nil
    var showFlash: Bool = false
    var capturedImage: UIImage? = nil
    var isProcessing: Bool = false

    var isBodyAligned: Bool = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()

    let gestureController = GestureController()
    @ObservationIgnored private let visionProcessor = VisionProcessor()
    @ObservationIgnored private var frameCounter = 0
    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    override init() {
        super.init()
        checkPermission()
    }

    deinit {
        session.stopRunning()
        countdownTask?.cancel()
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.isAuthorized = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func setupSession() {
        guard !session.isRunning else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            return
        }

        session.addInput(videoInput)

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        let cameraQueue = DispatchQueue(label: "com.workouttracker.smartcamera", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
                connection.isVideoMirrored = true
            }
        }

        session.commitConfiguration()
        Task.detached { [weak self] in self?.session.startRunning() }
    }

    func startCountdown() {
        guard countdownTask == nil else { return } 

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        countdownTask = Task {
            for i in (1...3).reversed() {
                guard !Task.isCancelled else { return }
                self.countdown = i
                AudioServicesPlaySystemSound(1104) 
                try? await Task.sleep(for: .seconds(1))
            }

            guard !Task.isCancelled else { return }
            self.countdown = nil
            self.takePhoto()
        }
    }

    private func takePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)

        withAnimation(.linear(duration: 0.1)) { showFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { self.showFlash = false }
        }
        AudioServicesPlaySystemSound(1108) 
    }

    func retake() {
        capturedImage = nil
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func checkBodyAlignment(joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        guard let leftShoulder = joints[.leftShoulder],
              let rightShoulder = joints[.rightShoulder],
              let leftHip = joints[.leftHip],
              let rightHip = joints[.rightHip] else {
            if isBodyAligned { isBodyAligned = false }
            return
        }

        let minX: CGFloat = 0.15
        let maxX: CGFloat = 0.85
        let minY: CGFloat = 0.10
        let maxY: CGFloat = 0.90

        let allPoints = [leftShoulder, rightShoulder, leftHip, rightHip]

        let isInsideBounds = allPoints.allSatisfy { pt in
            pt.x > minX && pt.x < maxX && pt.y > minY && pt.y < maxY
        }

        let torsoHeight = abs(((leftShoulder.y + rightShoulder.y) / 2) - ((leftHip.y + rightHip.y) / 2))
        let isLargeEnough = torsoHeight > 0.15

        let aligned = isInsideBounds && isLargeEnough

        if isBodyAligned != aligned {
            withAnimation(.easeInOut(duration: 0.3)) {
                isBodyAligned = aligned
            }
        }
    }
}

extension SmartCaptureViewModel: AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor in
            guard countdown == nil, capturedImage == nil else { return } 

            frameCounter += 1
            guard frameCounter % 5 == 0 else { return } 

            do {
                let result = try await visionProcessor.process(sampleBuffer: sampleBuffer)

                self.checkBodyAlignment(joints: result.joints)

                if let hand = result.handPose {
                    gestureController.processHandPose(observation: hand)

                    if gestureController.didConfirmSet {
                        gestureController.didConfirmSet = false
                        if self.isBodyAligned {
                            startCountdown()
                        }
                    }
                }
            } catch {
                print("Vision error: \(error)")
            }
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }

        let flippedImage = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .leftMirrored)

        Task { @MainActor in
            self.capturedImage = flippedImage
        }
    }
}

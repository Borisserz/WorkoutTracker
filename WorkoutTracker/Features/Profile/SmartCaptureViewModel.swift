

import Foundation
import OSLog
internal import SwiftUI
import AVFoundation
import Vision
import Observation
import Combine

@MainActor
@Observable
final class SmartCaptureViewModel: NSObject {

    var isAuthorized: Bool = false
    var authorizationDenied: Bool = false
    var countdown: Int? = nil
    var showFlash: Bool = false
    var capturedImage: UIImage? = nil
    var isProcessing: Bool = false
    var captureFailed: Bool = false
    var isBodyAligned: Bool = false

    nonisolated(unsafe) let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()

    let gestureController = GestureController()
    @ObservationIgnored private nonisolated let visionProcessor = VisionProcessor()
    @ObservationIgnored private nonisolated let captureFrameCounter = FrameCounter()
    @ObservationIgnored private nonisolated let capturePausedLock = NSLock()
    @ObservationIgnored private nonisolated(unsafe) var isCapturePaused = false
    @ObservationIgnored nonisolated(unsafe) private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    var cameraUnavailable: Bool = false

    override init() {
        super.init()
        checkPermission()
        setupGestureSubscription()
    }

    private func setupGestureSubscription() {
        gestureController.gestureAction
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                guard let self else { return }
                if action == .confirmSet, self.isBodyAligned {
                    self.startCountdown()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        countdownTask?.cancel()
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        let captureSession = session
        Task.detached {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    func stopSession() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
        setCapturePaused(false)
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        let captureSession = session
        Task.detached {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    func resumeSessionIfNeeded() {
        guard isAuthorized, !cameraUnavailable, !session.isRunning else { return }
        let cameraQueue = DispatchQueue(label: "com.workouttracker.smartcamera", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        let captureSession = session
        Task.detached {
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            authorizationDenied = false
            setupSession()
        case .notDetermined:
            authorizationDenied = false
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.isAuthorized = granted
                    self?.authorizationDenied = !granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            isAuthorized = false
            authorizationDenied = true
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
            cameraUnavailable = true
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
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                } else if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                connection.isVideoMirrored = true
            }
        }

        session.commitConfiguration()
        cameraUnavailable = false
        let captureSession = session
        Task.detached {
            captureSession.startRunning()
        }
    }

    func triggerManualCapture() {
        guard countdown == nil, capturedImage == nil else { return }
        startCountdown()
    }

    private func setCapturePaused(_ paused: Bool) {
        capturePausedLock.lock()
        isCapturePaused = paused
        capturePausedLock.unlock()
    }

    func startCountdown() {
        guard countdownTask == nil else { return }
        setCapturePaused(true)
        HapticManager.shared.notification(.success)

        countdownTask = Task {
            for i in (1...3).reversed() {
                guard !Task.isCancelled else {
                    self.setCapturePaused(false)
                    return
                }
                self.countdown = i
                AudioServicesPlaySystemSound(1104)
                try? await Task.sleep(for: .seconds(1))
            }

            guard !Task.isCancelled else {
                self.setCapturePaused(false)
                return
            }
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

    /// Called when photo capture fails. Resets capture state so the user can retry,
    /// instead of leaving the flow silently stuck.
    private func handleCaptureFailure() {
        captureFailed = true
        countdown = nil
        countdownTask?.cancel()
        countdownTask = nil
        setCapturePaused(false)
    }

    func retake() {
        capturedImage = nil
        countdownTask?.cancel()
        countdownTask = nil
        setCapturePaused(false)
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
        capturePausedLock.lock()
        let paused = isCapturePaused
        capturePausedLock.unlock()
        guard !paused else { return }

        guard captureFrameCounter.incrementAndCheck(stride: 5) else { return }

        do {
            let result = try visionProcessor.process(sampleBuffer: sampleBuffer)
            let joints = result.joints
            let handPose = result.handPose

            Task { @MainActor [weak self] in
                guard let self, self.countdown == nil, self.capturedImage == nil else { return }
                self.checkBodyAlignment(joints: joints)
                if let hand = handPose {
                    self.gestureController.processHandPose(observation: hand)
                }
            }
        } catch {
            AppLog.ml.error("Vision error: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            AppLog.ml.error("Photo capture error: \(error.localizedDescription, privacy: .public)")
            Task { @MainActor in self.handleCaptureFailure() }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in self.handleCaptureFailure() }
            return
        }

        // Normalize into upright pixels (and mirror horizontally for front camera)
        // instead of hardcoding .leftMirrored which rotates portrait buffers 90 degrees.
        guard let cgImage = image.normalizedUpMirroredCGImage() else {
            Task { @MainActor in self.handleCaptureFailure() }
            return
        }

        let finalImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)

        Task { @MainActor in
            self.capturedImage = finalImage
        }
    }
}

private extension UIImage {
    /// Renders an upright, horizontally mirrored CGImage regardless of sensor orientation metadata.
    nonisolated func normalizedUpMirroredCGImage() -> CGImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { ctx in
            ctx.cgContext.translateBy(x: size.width, y: 0)
            ctx.cgContext.scaleBy(x: -1, y: 1)
            draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
}

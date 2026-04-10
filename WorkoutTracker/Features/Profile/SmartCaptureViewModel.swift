//
//  SmartCaptureViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 10.04.26.
//

// ============================================================
// FILE: WorkoutTracker/Features/Profile/SmartCamera/SmartCaptureViewModel.swift
// ============================================================

import Foundation
internal import SwiftUI
import AVFoundation
import Vision
import Observation

@MainActor
@Observable
final class SmartCaptureViewModel: NSObject {
    // UI State
    var isAuthorized: Bool = false
    var countdown: Int? = nil
    var showFlash: Bool = false
    var capturedImage: UIImage? = nil
    var isProcessing: Bool = false
    
    // Core Components
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
        guard countdownTask == nil else { return } // Prevent multiple triggers
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        countdownTask = Task {
            for i in (1...3).reversed() {
                guard !Task.isCancelled else { return }
                self.countdown = i
                AudioServicesPlaySystemSound(1104) // Tick sound
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
        
        // Trigger Flash UI
        withAnimation(.linear(duration: 0.1)) { showFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { self.showFlash = false }
        }
        AudioServicesPlaySystemSound(1108) // Shutter sound
    }
    
    func retake() {
        capturedImage = nil
        countdownTask?.cancel()
        countdownTask = nil
    }
}

// MARK: - Video & Photo Delegates
extension SmartCaptureViewModel: AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    
    // Video frames for Vision (Gesture recognition)
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor in
            guard countdown == nil, capturedImage == nil else { return } // Stop ML if counting down or captured
            
            frameCounter += 1
            guard frameCounter % 5 == 0 else { return } // Throttle ML to save CPU
            
            do {
                let result = try await visionProcessor.process(sampleBuffer: sampleBuffer)
                if let hand = result.handPose {
                    gestureController.processHandPose(observation: hand)
                    if gestureController.didConfirmSet {
                        gestureController.didConfirmSet = false
                        startCountdown()
                    }
                }
            } catch {
                print("Vision error: \(error)")
            }
        }
    }
    
    // Photo Capture Result
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        
        // Flip image if front camera is used to match what user saw
        let flippedImage = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .leftMirrored)
        
        Task { @MainActor in
            self.capturedImage = flippedImage
        }
    }
}

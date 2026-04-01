//
//  CameraManager.swift
//  WorkoutTracker
//

internal import SwiftUI
import AVFoundation
import Vision
import Combine

// MARK: - Camera Manager
@MainActor
final class CameraManager: NSObject, ObservableObject {
    @Published var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var handPose: VNHumanHandPoseObservation? = nil
    @Published var bodyPose: VNHumanBodyPoseObservation? = nil
    @Published var isAuthorized = false
    
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let cameraQueue = DispatchQueue(label: "com.workouttracker.cameraQueue", qos: .userInitiated)
    private var cameraDelegate: CameraDelegate?
    
    override init() { super.init() }
    
    deinit {
            videoOutput.setSampleBufferDelegate(nil, queue: nil)
            if session.isRunning {
                session.stopRunning()
            }
            print("♻️ CameraManager deallocated, Vision pipeline cleared")
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
        
        // 🎼 Снижаем разрешение. Огромная экономия энергии и CPU.
        // Для детекции скелета в Vision VGA разрешения более чем достаточно.
        session.sessionPreset = .vga640x480
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(videoInput)
        
        let delegate = CameraDelegate(
            onUpdate: { [weak self] newJoints in
                Task { @MainActor in self?.joints = newJoints }
            },
            onBodyPoseUpdate: { [weak self] newBodyPose in
                Task { @MainActor in self?.bodyPose = newBodyPose }
            },
            onHandUpdate: { [weak self] newHandPose in
                Task { @MainActor in self?.handPose = newHandPose }
            }
        )
        self.cameraDelegate = delegate
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(delegate, queue: cameraQueue)
        
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
    
    func stopSession() {
        if session.isRunning {
            Task.detached { [weak self] in self?.session.stopRunning() }
        }
    }
}// MARK: - Frame Counter Actor (Concurrency Safe)
/// ОПТИМИЗАЦИЯ: Изолированный актор для безопасного инкремента счетчика кадров
/// в многопоточной среде (заменяет устаревший NSLock).
actor FrameCounter {
    private var count = 0
    
    func incrementAndCheck(stride: Int) -> Bool {
        count += 1
        return count % stride == 0
    }
}

// MARK: - Camera Delegate
/// Удалили @unchecked Sendable, так как делегат теперь полностью безопасен (Strict Concurrency).
final class CameraDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    private let onUpdate: @Sendable ([VNHumanBodyPoseObservation.JointName: CGPoint]) -> Void
    private let onBodyPoseUpdate: @Sendable (VNHumanBodyPoseObservation?) -> Void
    private let onHandUpdate: @Sendable (VNHumanHandPoseObservation?) -> Void
    
    // 🚩 ОПТИМИЗАЦИЯ: Создаем тяжелые реквесты ОДИН РАЗ при инициализации
    private let bodyRequest = VNDetectHumanBodyPoseRequest()
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let req = VNDetectHumanHandPoseRequest()
        req.maximumHandCount = 1
        return req
    }()
    
    // Используем актор вместо NSLock
    private let frameCounter = FrameCounter()
    
    init(
        onUpdate: @escaping @Sendable ([VNHumanBodyPoseObservation.JointName: CGPoint]) -> Void,
        onBodyPoseUpdate: @escaping @Sendable (VNHumanBodyPoseObservation?) -> Void,
        onHandUpdate: @escaping @Sendable (VNHumanHandPoseObservation?) -> Void
    ) {
        self.onUpdate = onUpdate
        self.onBodyPoseUpdate = onBodyPoseUpdate
        self.onHandUpdate = onHandUpdate
        super.init()
    }
    
    // Метод делегата не является async, поэтому оборачиваем логику в Task
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        Task {
            // Безопасно проверяем счетчик через актор (обрабатываем каждый 3-й кадр)
            let shouldProcess = await frameCounter.incrementAndCheck(stride: 3)
            guard shouldProcess else { return }
            
            // 🛡 Обертка autoreleasepool очищает память от тяжелых
            // объектов Vision сразу после завершения скоупа.
            autoreleasepool {
                let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
                
                do {
                    try handler.perform([bodyRequest, handRequest])
                    
                    // --- 1. Обработка Body (Скелет тела) ---
                    if let bodyObservation = bodyRequest.results?.first {
                        self.onBodyPoseUpdate(bodyObservation)
                        
                        if let recognizedPoints = try? bodyObservation.recognizedPoints(.all) {
                            var normalizedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
                            for (key, point) in recognizedPoints where point.confidence > 0.3 {
                                normalizedJoints[key] = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
                            }
                            self.onUpdate(normalizedJoints)
                        }
                    } else {
                        self.onBodyPoseUpdate(nil)
                        self.onUpdate([:])
                    }
                    
                    // --- 2. Обработка Hand (Кисть для жестов) ---
                    self.onHandUpdate(handRequest.results?.first)
                    
                } catch {
                    print("Vision request failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}

// MARK: - Pose Overlay View
struct PoseOverlayView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    private static let lines: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder), (.neck, .rightShoulder), (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip), (.leftHip, .rightHip),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist), (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle), (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.neck, .nose), (.nose, .leftEye), (.nose, .rightEye), (.leftEye, .leftEar), (.rightEye, .rightEar)
    ]
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    for line in Self.lines {
                        if let p1 = joints[line.0], let p2 = joints[line.1] {
                            path.move(to: CGPoint(x: p1.x * geometry.size.width, y: p1.y * geometry.size.height))
                            path.addLine(to: CGPoint(x: p2.x * geometry.size.width, y: p2.y * geometry.size.height))
                        }
                    }
                }
                .stroke(Color.green.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                ForEach(Array(joints.keys), id: \.self) { key in
                    if let point = joints[key] {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                            .position(x: point.x * geometry.size.width, y: point.y * geometry.size.height)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

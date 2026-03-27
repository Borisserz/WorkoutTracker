internal import SwiftUI
import AVFoundation
import Vision
import Combine

// MARK: - Camera Manager
@MainActor
final class CameraManager: NSObject, ObservableObject {
    @Published var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var handPose: VNHumanHandPoseObservation? = nil
    
    // ДОБАВЛЕНО: Публикуем сырой кадр для Core ML
    @Published var bodyPose: VNHumanBodyPoseObservation? = nil
    
    @Published var isAuthorized = false
    
    let session = AVCaptureSession()
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let cameraQueue = DispatchQueue(label: "com.workouttracker.cameraQueue", qos: .userInitiated)
    
    private var cameraDelegate: CameraDelegate?
    
    override init() {
        super.init()
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
        session.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(videoInput)
        
        // ОБНОВЛЕНО: Передаем 3 коллбека (точки тела, сырое тело для ML, и руки)
        let delegate = CameraDelegate(
            onUpdate: { [weak self] newJoints in
                Task { @MainActor in self?.joints = newJoints }
            },
            onBodyPoseUpdate: { [weak self] newBodyPose in
                Task { @MainActor in self?.bodyPose = newBodyPose } // Прокидываем в MainActor
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
                connection.isVideoMirrored = true // Фронталка как зеркало
            }
        }
        
        session.commitConfiguration()
        
        Task.detached { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        if session.isRunning {
            Task.detached { [weak self] in
                self?.session.stopRunning()
            }
        }
    }
}

// MARK: - Safe Camera Delegate (Фоновый поток)
final class CameraDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let onUpdate: @Sendable ([VNHumanBodyPoseObservation.JointName: CGPoint]) -> Void
    private let onBodyPoseUpdate: @Sendable (VNHumanBodyPoseObservation?) -> Void
    private let onHandUpdate: @Sendable (VNHumanHandPoseObservation?) -> Void
    
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
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let bodyRequest = VNDetectHumanBodyPoseRequest { [weak self] req, err in
            self?.handleBodyPose(request: req, error: err)
        }
        
        let handRequest = VNDetectHumanHandPoseRequest { [weak self] req, err in
            self?.handleHandPose(request: req, error: err)
        }
        handRequest.maximumHandCount = 1
        
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([bodyRequest, handRequest])
        } catch {
            print("Vision request failed: \(error.localizedDescription)")
        }
    }
    
    nonisolated private func handleBodyPose(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNHumanBodyPoseObservation],
              let observation = observations.first else {
            onUpdate([:])
            onBodyPoseUpdate(nil)
            return
        }
        
        // ПЕРЕДАЕМ СЫРОЙ КАДР НАРУЖУ
        onBodyPoseUpdate(observation)
        
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        var normalizedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        
        for (key, point) in recognizedPoints where point.confidence > 0.3 {
            normalizedJoints[key] = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
        }
        onUpdate(normalizedJoints)
    }
    
    nonisolated private func handleHandPose(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNHumanHandPoseObservation],
              let observation = observations.first else {
            onHandUpdate(nil)
            return
        }
        onHandUpdate(observation)
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
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
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.neck, .nose), (.nose, .leftEye), (.nose, .rightEye),
        (.leftEye, .leftEar), (.rightEye, .rightEar)
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
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .position(x: point.x * geometry.size.width, y: point.y * geometry.size.height)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

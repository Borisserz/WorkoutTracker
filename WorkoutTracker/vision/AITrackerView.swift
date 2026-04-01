//
//  AITrackerView.swift
//  WorkoutTracker
//

internal import SwiftUI
import AVFoundation
import Vision
struct AITrackerView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var engine: AITrackerEngine
    
    @StateObject private var gestureCtrl = GestureController()
    @StateObject private var coach = VoiceCoach()
    
    @State private var repScale: CGFloat = 1.0
    
    var onFinish: ((Int) -> Void)?
    
    // 1. ДОБАВЛЯЕМ СВОЙСТВО ДЛЯ ХРАНЕНИЯ ИМЕНИ
    let exerciseName: String
    
    // 2. ИСПОЛЬЗУЕМ СОХРАНЕННОЕ ИМЯ (а не engine.exerciseName)
    private var isBackExercise: Bool {
        let name = exerciseName.lowercased()
        let backKeywords = ["deadlift", "row", "pull", "chin", "tricep", "glute", "hamstring", "calf", "calves", "back", "good morning", "shrug"]
        return backKeywords.contains { name.contains($0) }
    }
    
    init(exerciseName: String, onFinish: ((Int) -> Void)? = nil) {
        // 3. СОХРАНЯЕМ ИМЯ ПРИ ИНИЦИАЛИЗАЦИИ
        self.exerciseName = exerciseName
        
        _engine = StateObject(wrappedValue: AITrackerEngine(exerciseName: exerciseName))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
            
            PoseOverlayView(joints: cameraManager.joints)
                .ignoresSafeArea()
            
            VStack {
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 250)
            }
            .ignoresSafeArea()
            
            VStack {
                topHUD
                Spacer()
                
                HStack(alignment: .bottom) {
                    liveMusclePiP
                    Spacer()
                    gestureHUD
                }
                .padding(.bottom, 10)
                
                finishButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .navigationBarHidden(true)
        .onAppear {
            cameraManager.checkPermission()
            coach.speak("Ready. Let's go!")
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: cameraManager.bodyPose) { newPose in
            if let pose = newPose {
                engine.processFrame(observation: pose)
            }
        }
        .onChange(of: cameraManager.handPose) { newHandPose in
            if let pose = newHandPose {
                gestureCtrl.processHandPose(observation: pose)
            }
        }
        .onChange(of: engine.repsCount) { _ in
            triggerRepAnimation()
            coach.speak("\(engine.repsCount)")
        }
        .onChange(of: gestureCtrl.didConfirmSet) { confirmed in
            if confirmed {
                coach.speak("Set completed! Great job.")
                onFinish?(engine.repsCount)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
        .onChange(of: gestureCtrl.didCancelSet) { canceled in
            if canceled {
                coach.speak("Tracker canceled.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Live Muscle Activation UI

        @ViewBuilder
        private var liveMusclePiP: some View {
            BodyHeatmapView(
                muscleIntensities: engine.liveMuscleTension,
                isRecoveryMode: false,
                isCompactMode: true,
                defaultToBack: isBackExercise // ДОБАВЛЕНО: Передаем вычисленную сторону
            )
            .frame(width: 100, height: 220)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(engine.isTrackingAction ? Color.blue.opacity(0.8) : Color.gray.opacity(0.5),
                            lineWidth: engine.isTrackingAction ? 3 : 2)
            )
            .shadow(color: engine.isTrackingAction ? .blue.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
            .animation(.easeInOut(duration: 0.2), value: engine.isTrackingAction)
            .animation(.easeInOut(duration: 0.1), value: engine.liveMuscleTension)
        }
    // MARK: - Gesture UI
    @ViewBuilder
    private var gestureHUD: some View {
        if gestureCtrl.activeGesture != .none {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(gestureCtrl.gestureProgress))
                    .stroke(gestureCtrl.activeGesture == .victory ? Color.green : Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: gestureCtrl.gestureProgress)
                
                if gestureCtrl.activeGesture == .victory {
                    Text("✌️")
                        .font(.system(size: 38))
                } else {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.red)
                }
            }
            .background(Color.black.opacity(0.6).clipShape(Circle()))
            .transition(.scale.combined(with: .opacity))
        } else {
            Color.clear.frame(width: 80, height: 80)
        }
    }
    
    // MARK: - HUDs
    private var topHUD: some View {
        VStack(spacing: 8) {
            Text("\(engine.repsCount)")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText(value: Double(engine.repsCount)))
                .scaleEffect(repScale)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(engine.isTrackingAction ? Color.blue : Color.white.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .animation(.easeInOut(duration: 0.2), value: engine.isTrackingAction)
                
                Text(LocalizedStringKey(engine.feedbackMessage))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(feedbackColor(for: engine.feedbackMessage))
                                    .animation(.easeInOut(duration: 0.2), value: engine.feedbackMessage)
                            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.4))
            .clipShape(Capsule())
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.top, 10)
    }
    
    private var finishButton: some View {
        Button(action: {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            onFinish?(engine.repsCount)
            dismiss()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                Text("Finish Set")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
        }
        .padding(.bottom, 20)
    }
    
    private func feedbackColor(for message: String) -> Color {
            let lowercased = message.lowercased()
            if lowercased.contains("occluded") || lowercased.contains("adjust") {
                return .orange
            } else if lowercased.contains("tracking") {
                return .green
            } else {
                return .white
            }
        }
    
    private func triggerRepAnimation() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4, blendDuration: 0)) {
            repScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
                repScale = 1.0
            }
        }
    }
}

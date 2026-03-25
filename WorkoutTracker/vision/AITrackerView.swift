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
    // ИСПРАВЛЕНИЕ: Используем новый движок
    @StateObject private var engine: AITrackerEngine
    
    @State private var repScale: CGFloat = 1.0
    var onFinish: ((Int) -> Void)?
    
    // ДОБАВЛЕНО: Инициализатор, принимающий имя упражнения
    init(exerciseName: String, onFinish: ((Int) -> Void)? = nil) {
        // Инициализируем StateObject с нужным упражнением
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
                    .frame(height: 150)
            }
            .ignoresSafeArea()
            
            VStack {
                topHUD
                Spacer()
                finishButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .navigationBarHidden(true)
        .onAppear {
            cameraManager.checkPermission()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: cameraManager.joints) { newJoints in
            engine.processFrame(joints: newJoints)
        }
        .onChange(of: engine.repsCount) { _ in
            triggerRepAnimation()
        }
    }
    
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
                    // ИСПРАВЛЕНИЕ: Теперь используем isTrackingAction
                    .fill(engine.isTrackingAction ? Color.blue : Color.white.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .animation(.easeInOut(duration: 0.2), value: engine.isTrackingAction)
                
                Text(engine.feedbackMessage)
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
        // Оранжевый для предупреждений об осанке/читинге
        if lowercased.contains("straight") || lowercased.contains("don't") || lowercased.contains("swing") {
            return .orange
        } else if lowercased.contains("perfect") || lowercased.contains("great") || lowercased.contains("good") {
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

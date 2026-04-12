//
//  TutorialManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI
import Combine
import Observation
// 1. ШАГИ (Без изменений)
enum TutorialStep: Int, CaseIterable, Equatable {
    case tapPlus = 0, createEmpty,tapStartNow, addExercise, finishExercise, explainEffort, highlightChart, highlightBody, finishWorkout, recoveryCheck, recoverySlider, historyTab, exercisesTab, createCustom, progressTab, completed
}
@Observable
class TutorialManager {
    var currentStep: TutorialStep
    private let kHasSeenTutorial = "hasSeenTutorial_Final_v8"

    init() {
        // ✅ FIX: Принудительно отключаем туториал, так как онбординг удален.
        // Теперь пользователь не увидит Spotlight-подсказки при первом запуске.
        self.currentStep = .completed
        UserDefaults.standard.set(true, forKey: kHasSeenTutorial)
    }
    
    func nextStep() {
        withAnimation {
            if let next = TutorialStep(rawValue: currentStep.rawValue + 1) {
                currentStep = next
            } else {
                complete()
            }
        }
    }
    
    func setStep(_ step: TutorialStep) {
        withAnimation { currentStep = step }
    }
    
    func complete() {
        currentStep = .completed
        UserDefaults.standard.set(true, forKey: kHasSeenTutorial)
    }
    
    func reset() {
        UserDefaults.standard.set(false, forKey: kHasSeenTutorial)
        currentStep = .tapPlus
    }
}

// 3. НОВЫЙ МОДИФИКАТОР
extension View {
    func spotlight(
        step: TutorialStep,
        manager: TutorialManager,
        text: String,
        alignment: VerticalAlignment = .top,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0
    ) -> some View {
        self.overlay(
            SpotlightOverlayView(
                isActive: manager.currentStep == step,
                text: text,
                alignment: alignment,
                xOffset: xOffset,
                yOffset: yOffset
            )
            .zIndex(999)
        )
    }
}

// MARK: - View Оверлея (Метод 4-х стен)
struct SpotlightOverlayView: View {
    let isActive: Bool
    let text: String
    let alignment: VerticalAlignment
    let xOffset: CGFloat
    let yOffset: CGFloat
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var shakeTrigger: CGFloat = 0
    
    // Большой размер для перекрытия экрана
    let wallSize: CGFloat = 4000
    
    var body: some View {
        if isActive {
            GeometryReader { geo in
                let frame = geo.frame(in: .local)
                let w = frame.width
                let h = frame.height
                
                ZStack {
                    // --- 4 НЕВИДИМЫЕ СТЕНЫ ВОКРУГ КНОПКИ ---
                    // Они ловят нажатия МИМО кнопки. Центр остается пустым.
                    
                    // 1. Верхняя стена
                    Color.black.opacity(0.01)
                        .frame(width: wallSize, height: wallSize)
                        .position(x: frame.midX, y: frame.minY - wallSize/2)
                        .onTapGesture { triggerShake() }
                    
                    // 2. Нижняя стена
                    Color.black.opacity(0.01)
                        .frame(width: wallSize, height: wallSize)
                        .position(x: frame.midX, y: frame.maxY + wallSize/2)
                        .onTapGesture { triggerShake() }
                    
                    // 3. Левая стена (по высоте элемента)
                    Color.black.opacity(0.01)
                        .frame(width: wallSize, height: h)
                        .position(x: frame.minX - wallSize/2, y: frame.midY)
                        .onTapGesture { triggerShake() }
                    
                    // 4. Правая стена (по высоте элемента)
                    Color.black.opacity(0.01)
                        .frame(width: wallSize, height: h)
                        .position(x: frame.maxX + wallSize/2, y: frame.midY)
                        .onTapGesture { triggerShake() }

                    // --- ВИЗУАЛ (Рамка и Текст) ---
                    // allowsHitTesting(false) гарантирует, что визуальные элементы не блокируют нажатия
                    
                    // Рамка
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.current.primaryAccent, lineWidth: 3)
                        .shadow(color: themeManager.current.primaryAccent.opacity(0.8), radius: 8)
                        .frame(width: w + 8, height: h + 8)
                        .position(x: frame.midX, y: frame.midY)
                        .modifier(PulsatingEffect())
                        .allowsHitTesting(false)
                    
                    // Тултип
                    TooltipBubble(text: text, arrowDirection: alignment == .top ? .down : .up)
                        .fixedSize()
                        .position(
                            x: frame.midX + xOffset,
                            y: alignment == .top ? -50 + yOffset : h + 50 + yOffset
                        )
                        .modifier(ShakeEffect(animatableData: shakeTrigger))
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    func triggerShake() {
        withAnimation(.default) {
            shakeTrigger += 1
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Эффекты и UI
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

struct PulsatingEffect: ViewModifier {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    scale = 1.05
                    opacity = 0.6
                }
            }
            .onDisappear {
                scale = 1.0
                opacity = 1.0
            }
    }
}
enum TooltipArrowDirection {
    case up
    case down
}

struct TooltipBubble: View {
    let text: String
    let arrowDirection: TooltipArrowDirection
    
    var body: some View {
        VStack(spacing: 0) {
            if arrowDirection == .up {
                Triangle()
                    .fill(Color(UIColor.darkGray))
                    .frame(width: 20, height: 10)
                    .offset(y: 1)
            }
            
            Text(text)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.darkGray))
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                )
                .frame(maxWidth: 260)
            
            if arrowDirection == .down {
                Triangle()
                    .fill(Color(UIColor.darkGray))
                    .frame(width: 20, height: 10)
                    .rotationEffect(.degrees(180))
                    .offset(y: -1)
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

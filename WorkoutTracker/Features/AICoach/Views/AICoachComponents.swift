//
//  AICoachComponents.swift
//  WorkoutTracker
//

internal import SwiftUI

// MARK: - Chat Bubble View
struct ChatMessageView: View {
    let message: AIChatMessage
    var onAcceptWorkout: ((GeneratedWorkoutDTO) -> Void)? = nil
    
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО
    
    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser {
                Spacer(minLength: 40)
            } else {
                // Иконка AI
                ZStack {
                    Circle()
                        .fill(themeManager.current.premiumGradient) // <--- ИЗМЕНЕНО
                        .frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Текст сообщения
                Group {
                    if message.isUser {
                        Text(LocalizedStringKey(message.text))
                    } else {
                        TypewriterTextView(fullText: message.text, isAnimating: message.isAnimating)
                    }
                }
                .font(.body)
                .foregroundColor(message.isUser ? .white : .primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    message.isUser
                    ? themeManager.current.primaryAccent // <--- ИЗМЕНЕНО
                    : themeManager.current.surface
                )
                .clipShape(ChatBubbleShape(isUser: message.isUser))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // Карточка тренировки (если есть)
                if let workout = message.proposedWorkout {
                    ProposedWorkoutCardView(workout: workout, onAccept: {
                        onAcceptWorkout?(workout)
                    })
                    .padding(.top, 4)
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
        .transition(.move(edge: message.isUser ? .trailing : .leading).combined(with: .opacity))
    }
}
// MARK: - Typewriter Text View
struct TypewriterTextView: View {
    let fullText: String
    let isAnimating: Bool
    
    @State private var displayedText: String = ""
    @State private var timer: Timer?
    @State private var hasAnimated: Bool = false // ✅ ИСПРАВЛЕНИЕ: Локальный стейт
    
    var body: some View {
        Text(.init(displayedText))
            .onAppear {
                // ✅ Защита от повторной анимации при возврате на экран чата
                if isAnimating && !hasAnimated {
                    startAnimating()
                    hasAnimated = true
                } else {
                    displayedText = fullText
                }
            }
            .onChange(of: fullText) { _, newText in
                if !isAnimating {
                    displayedText = newText
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
    
    private func startAnimating() {
        displayedText = ""
        let chars = Array(fullText)
        var currentIndex = 0
        
        timer?.invalidate()
        // Оптимизированный таймер (15мс на символ)
        timer = Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { t in
            if currentIndex < chars.count {
                displayedText.append(chars[currentIndex])
                currentIndex += 1
            } else {
                t.invalidate()
            }
        }
    }
}

// MARK: - Custom Shape for Chat Bubbles
struct ChatBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .topLeft,
                .topRight,
                isUser ? .bottomLeft : .bottomRight
            ],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Smart AI Loading Indicator
struct AILoadingIndicator: View {
    @State private var isAnimating = false
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ZStack {
                Circle()
                    .fill(themeManager.current.premiumGradient) // <--- ИЗМЕНЕНО
                    .frame(width: 32, height: 32)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(y: isAnimating ? -5 : 0)
                        .animation(
                            Animation.easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(0.15 * Double(index)),
                            value: isAnimating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(themeManager.current.surface)
            .clipShape(ChatBubbleShape(isUser: false))
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Proposed Workout Card
struct ProposedWorkoutCardView: View {
    let workout: GeneratedWorkoutDTO
    var onAccept: () -> Void
    @Environment(ThemeManager.self) private var themeManager // <--- ДОБАВЛЕНО
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text(LocalizedStringKey(workout.title))
                    .font(.headline)
                    .foregroundColor(themeManager.current.primaryText)
                Spacer()
                Text("\(workout.exercises.count) exercises")
                    .font(.caption)
                    .foregroundColor(themeManager.current.secondaryText)
            }
            .padding()
            .background(themeManager.current.primaryAccent.opacity(0.1)) // <--- ИЗМЕНЕНО
            
            // Exercises List
            VStack(spacing: 12) {
                ForEach(workout.exercises, id: \.name) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizationHelper.shared.translateName(exercise.name))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.caption2)
                                Text(LocalizedStringKey(exercise.muscleGroup))
                                    .font(.caption)
                            }
                            .foregroundColor(themeManager.current.secondaryText)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(exercise.sets) x \(exercise.reps)")
                                .font(.subheadline)
                                .bold()
                            
                            if let weight = exercise.recommendedWeightKg, weight > 0 {
                                Text("\(Int(weight)) kg")
                                    .font(.caption)
                                    .foregroundColor(themeManager.current.primaryAccent) // <--- ИЗМЕНЕНО
                            }
                        }
                    }
                    if exercise.name != workout.exercises.last?.name {
                        Divider()
                    }
                }
            }
            .padding()
            
            // Action Button
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onAccept()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text(LocalizedStringKey("Accept & Start Workout"))
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeManager.current.primaryAccent) // <--- ИЗМЕНЕНО
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(themeManager.current.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.current.primaryAccent.opacity(0.3), lineWidth: 1) // <--- ИЗМЕНЕНО
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .frame(maxWidth: 340)
    }
}

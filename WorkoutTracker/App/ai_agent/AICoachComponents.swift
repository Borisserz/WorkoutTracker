//
//  AICoachComponents.swift
//  WorkoutTracker
//

internal import SwiftUI

// MARK: - Chat Bubble View
struct ChatMessageView: View {
    let message: AIChatMessage
    
    // Замыкание для передачи события нажатия кнопки наверх
    var onAcceptWorkout: ((GeneratedWorkoutDTO) -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser {
                Spacer(minLength: 40)
            } else {
                // Иконка AI
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Текст сообщения с поддержкой Markdown (LocalizedStringKey автоматически парсит **bold**, *italic* и списки)
                Text(LocalizedStringKey(message.text))
                    .font(.body)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .multilineTextAlignment(.leading) // Важно для корректного отображения списков
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.isUser
                        ? Color.accentColor
                        : Color(UIColor.secondarySystemBackground)
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
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                        // Анимация волны (Wave Effect)
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
            .background(Color(UIColor.secondarySystemBackground))
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text(LocalizedStringKey(workout.title))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(workout.exercises.count) exercises")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            
            // Exercises List
            VStack(spacing: 12) {
                ForEach(workout.exercises, id: \.name) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey(exercise.name))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.caption2)
                                Text(LocalizedStringKey(exercise.muscleGroup))
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(exercise.sets) x \(exercise.reps)")
                                .font(.subheadline)
                                .bold()
                            
                            if let weight = exercise.recommendedWeightKg, weight > 0 {
                                Text("\(Int(weight)) kg")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
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
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .frame(maxWidth: 340)
    }
}

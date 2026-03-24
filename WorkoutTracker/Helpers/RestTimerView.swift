//
//  RestTimerView.swift
//  WorkoutTracker
//

internal import SwiftUI

struct RestTimerView: View {
    @EnvironmentObject var timerManager: RestTimerManager
    
    // Анимация пульсации для завершения
    @State private var isPulsing = false
    
    var body: some View {
        if timerManager.isRestTimerActive {
            HStack(spacing: 16) {
                
                // Левая часть: Иконка + Время
                HStack(spacing: 6) {
                    Image(systemName: timerManager.restTimerFinished ? "checkmark.circle.fill" : "timer")
                        .foregroundColor(timerManager.restTimerFinished ? .green : .white)
                        .symbolEffect(.bounce, value: timerManager.restTimerFinished)
                    
                    Text(timerManager.restTimerFinished ? "DONE" : timeString(time: timerManager.restTimeRemaining))
                        .font(.title3.monospacedDigit())
                        .bold()
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Правая часть: Управление
                if !timerManager.restTimerFinished {
                    HStack(spacing: 16) {
                        Button {
                            timerManager.subtractRestTime(30)
                        } label: {
                            Text("-30")
                                .font(.subheadline.bold())
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Button {
                            timerManager.addRestTime(30)
                        } label: {
                            Text("+30")
                                .font(.subheadline.bold())
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        // Кнопка закрытия
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                timerManager.stopRestTimer()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            // Эффект матового стекла + темная тема (всегда выглядит красиво и читаемо)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            // Легкая цветовая подложка (Синяя пока идет время, зеленая когда окончено)
            .background(
                Capsule()
                    .fill(timerManager.restTimerFinished ? Color.green.opacity(0.3) : Color.blue.opacity(0.3))
            )
            // Тонкая белая рамка для объема
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            
            // Анимации появления и пульсации
            .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
            .scaleEffect(isPulsing ? 1.04 : 1.0)
            .onChange(of: timerManager.restTimerFinished) { finished in
                if finished {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
        }
    }
    
    func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

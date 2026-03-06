//
//  RestTimerView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 28.12.25.
//

internal import SwiftUI

struct RestTimerView: View {
    @EnvironmentObject var timerManager: RestTimerManager
    
    // Анимация пульсации для завершения
    @State private var isPulsing = false
    
    var body: some View {
        if timerManager.isRestTimerActive {
            HStack(spacing: 15) {
                
                HStack(spacing: 8) {
                    Image(systemName: timerManager.restTimerFinished ? "checkmark.circle.fill" : "timer")
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, value: timerManager.restTimerFinished) // Анимация иконки (iOS 17+)
                    
                    Text(timerManager.restTimerFinished ? "DONE" : timeString(time: timerManager.restTimeRemaining))
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                
                Spacer()
                
                // Скрываем кнопки +/- когда таймер уже звонит (finished)
                if !timerManager.restTimerFinished {
                    HStack(spacing: 12) {
                        
                        // Кнопка -30
                        Button {
                            timerManager.subtractRestTime(30)
                        } label: {
                            Text("-30")
                                .font(.caption).bold()
                                .frame(width: 35, height: 30)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                        
                        // Кнопка +30
                        Button {
                            timerManager.addRestTime(30)
                        } label: {
                            Text("+30")
                                .font(.caption).bold()
                                .frame(width: 35, height: 30)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                        
                        // Разделитель
                        Divider()
                            .frame(height: 20)
                            .background(Color.white.opacity(0.5))
                        
                        // Кнопка Стоп
                        Button {
                            withAnimation {
                                timerManager.stopRestTimer()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .padding()
            // Меняем цвет фона: Синий (идет время) -> Зеленый (готово)
            .background(timerManager.restTimerFinished ? Color.green.gradient : Color.blue.gradient)
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            // Анимация появления/исчезновения
            .transition(.move(edge: .bottom).combined(with: .opacity))
            
            // Анимация пульсации при завершении
            .scaleEffect(isPulsing ? 1.05 : 1.0)
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

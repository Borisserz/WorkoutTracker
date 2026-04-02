//
//  EffortInputView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 30.12.25.
//

internal import SwiftUI

struct EffortInputView: View {
    @Binding var effort: Int
    @Environment(\.dismiss) var dismiss
    @Environment(TutorialManager.self) var tutorialManager
    
    // Локальное состояние для слайдера - обновляется мгновенно без задержек
    @State private var localEffort: Int = 5
    @State private var updateTask: Task<Void, Never>?
    @State private var isDragging: Bool = false
    
    func effortColor(_ value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
    
    // Binding для слайдера с локальным состоянием
    private var sliderBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(localEffort) },
            set: { newValue in
                let intValue = Int(newValue)
                localEffort = intValue
                handleSliderValueChange(intValue)
            }
        )
    }
    
    // Обрабатывает изменение значения слайдера с debounce
    private func handleSliderValueChange(_ newValue: Int) {
        // Отменяем предыдущую задачу
        updateTask?.cancel()
        
        // Отмечаем, что происходит перетаскивание
        if !isDragging {
            isDragging = true
        }
        
        // Обновляем binding с задержкой после последнего изменения
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            if !Task.isCancelled {
                await MainActor.run {
                    isDragging = false
                    effort = localEffort
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(LocalizedStringKey("Rate Your Effort"))
                .font(.title2).bold()
            
            // ОБЪЕДИНЯЕМ СЛАЙДЕР И КНОПКУ В ОДНУ ГРУППУ ДЛЯ ПОДСВЕТКИ
            VStack(spacing: 30) {
                
                // 1. Слайдер
                HStack {
                    Text("\(localEffort)/10")
                        .font(.title3.bold())
                        .foregroundColor(effortColor(localEffort))
                        .frame(width: 60)
                    
                    Slider(value: sliderBinding, in: 1...10, step: 1)
                        .tint(effortColor(localEffort))
                }
                
                // 2. Кнопка
                Button(LocalizedStringKey("Done")) {
                    // Отменяем любые ожидающие задачи
                    updateTask?.cancel()
                    // При закрытии сохраняем финальное значение
                    effort = localEffort
                    dismiss()
                    if tutorialManager.currentStep == .explainEffort {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            tutorialManager.setStep(.highlightChart)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .controlSize(.large)
            }
            // Это значит, что "дырка" будет большой, и кнопка будет нажиматься
            .spotlight(
                step: .explainEffort,
                manager: tutorialManager,
                text: "Select intensity and tap Done.",
                alignment: .top, // Текст СВЕРХУ слайдера
                yOffset: +10
            )
            
            Spacer()
        }
        .padding()
        .presentationDetents([.height(250)]) // Чуть увеличил высоту, чтобы все влезло комфортно
        .onAppear {
            // Инициализируем локальное значение при появлении
            localEffort = effort
        }
    }
}

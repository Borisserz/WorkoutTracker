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
    @EnvironmentObject var tutorialManager: TutorialManager
    
    func effortColor(_ value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rate Your Effort")
                .font(.title2).bold()
            
            // ОБЪЕДИНЯЕМ СЛАЙДЕР И КНОПКУ В ОДНУ ГРУППУ ДЛЯ ПОДСВЕТКИ
            VStack(spacing: 30) {
                
                // 1. Слайдер
                HStack {
                    Text("\(effort)/10")
                        .font(.title3.bold())
                        .foregroundColor(effortColor(effort))
                        .frame(width: 60)
                    
                    Slider(value: Binding(get: { Double(effort) }, set: { effort = Int($0) }), in: 1...10, step: 1)
                        .tint(effortColor(effort))
                }
                
                // 2. Кнопка
                Button("Done") {
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
            // ТЕПЕРЬ ПОДСВЕТКА ОХВАТЫВАЕТ И СЛАЙДЕР, И КНОПКУ
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
    }
}

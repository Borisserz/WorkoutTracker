//
//  ConfigureExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI

struct ConfigureExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    let exerciseName: String
    let muscleGroup: String
    
    var onAdd: (Exercise) -> Void
    
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var effort = 5
    
    // Состояние для отображения поздравления
    @State private var showPRCelebration = false
    
    // Вспомогательная функция цвета
    func effortColor(_ value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
    
    var body: some View {
        ZStack {
            // 1. ОСНОВНАЯ ФОРМА
            Form {
                Section(header: Text("Configuration")) {
                    HStack {
                        Text("Exercise")
                        Spacer()
                        Text(exerciseName).bold()
                    }
                    
                    Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                    Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                    
                    HStack {
                        Text("Weight (kg):")
                        TextField("0", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Effort (RPE)")) {
                    HStack {
                        Text("\(effort)/10")
                            .bold()
                            .foregroundColor(effortColor(effort))
                        Slider(value: Binding(get: { Double(effort) }, set: { effort = Int($0) }), in: 1...10, step: 1)
                            .tint(effortColor(effort))
                    }
                    Text("1 = Easy, 10 = Failure")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Add Exercise") {
                    handleSave()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            // Блокируем форму, пока показывается поздравление
            .disabled(showPRCelebration)
            .blur(radius: showPRCelebration ? 3 : 0) // Размываем фон для красоты
            
            // 2. ВСПЛЫВАЮЩЕЕ ПОЗДРАВЛЕНИЕ
            if showPRCelebration {
                VStack(spacing: 20) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                        .shadow(color: .orange, radius: 10)
                        .symbolEffect(.bounce, value: showPRCelebration) // Анимация прыжка
                    
                    Text("New Record!")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("You lifted \(Int(weight)) kg for the first time!")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .shadow(radius: 20)
                .transition(.scale.combined(with: .opacity))
                .zIndex(100)
            }
        }
        .navigationTitle("Configure")
    }
    
    // ЛОГИКА СОХРАНЕНИЯ
    func handleSave() {
        let newExercise = Exercise(
            name: exerciseName,
            muscleGroup: muscleGroup,
            sets: sets,
            reps: reps,
            weight: weight,
            effort: effort
        )
        
        // 1. Проверяем рекорд
        let currentRecord = viewModel.getPersonalRecord(for: exerciseName)
        
        // Если вес больше старого рекорда И больше 0
        if weight > currentRecord && weight > 0 {
            // ЭТО РЕКОРД!
            
            // Запускаем анимацию
            withAnimation(.spring()) {
                showPRCelebration = true
            }
            
            // Ждем 1.5 секунды, чтобы юзер насладился моментом
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onAdd(newExercise)
                dismiss()
            }
            
            // Тут можно добавить вибрацию
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        } else {
            // ОБЫЧНОЕ СОХРАНЕНИЕ (сразу закрываем)
            onAdd(newExercise)
            dismiss()
        }
    }
}

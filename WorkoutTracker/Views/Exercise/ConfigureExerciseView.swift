//
//  ConfigureExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI

struct ConfigureExerciseView: View {
    @Environment(\.dismiss) var dismiss
    
    // Принимаем имя, которое выбрали в каталоге
    let exerciseName: String
    let muscleGroup: String
    
    // Замыкание: передаем данные назад, когда нажали "Save"
    var onAdd: (Exercise) -> Void
    
    // Поля ввода
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var effort = 5
    
    // Вспомогательная функция цвета (дублируем или выносим в Utils)
    func effortColor(_ value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
    
    var body: some View {
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
                // Создаем упражнение
                let newExercise = Exercise(
                    name: exerciseName,
                    muscleGroup: muscleGroup,
                    sets: sets,
                    reps: reps,
                    weight: weight,
                    effort: effort
                )
                // Отправляем назад
                onAdd(newExercise)
                dismiss() // Закрываем
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Configure")
    }
}

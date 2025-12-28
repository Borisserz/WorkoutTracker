//
//  EditExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 25.12.25.
//

internal import SwiftUI


struct EditExerciseView: View {
    @Environment(\.dismiss) var dismiss
    
    // Принимаем "живую" ссылку на упражнение, чтобы менять его напрямую
    @Binding var exercise: Exercise
    
    // Локальные временные переменные для полей ввода
    @State private var sets: Int
    @State private var reps: Int
    @State private var weight: Double
    @State private var effort: Int
    
    // Вспомогательная функция цвета
    private func effortColor(_ value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
    
    // Инициализатор для заполнения полей начальными данными
    init(exercise: Binding<Exercise>) {
        self._exercise = exercise
        
        // Заполняем @State переменные значениями из упражнения
        _sets = State(initialValue: exercise.wrappedValue.sets)
        _reps = State(initialValue: exercise.wrappedValue.reps)
        _weight = State(initialValue: exercise.wrappedValue.weight)
        _effort = State(initialValue: exercise.wrappedValue.effort)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Configuration")) {
                HStack {
                    Text("Exercise")
                    Spacer()
                    // Название упражнения не меняется
                    Text(exercise.name).bold()
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
            
            // Кнопка для сохранения изменений
            Button("Save Changes") {
                // Обновляем оригинальное упражнение через binding
                exercise.sets = sets
                exercise.reps = reps
                exercise.weight = weight
                exercise.effort = effort
                
                dismiss() // Закрываем экран
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Edit Exercise")
    }
}


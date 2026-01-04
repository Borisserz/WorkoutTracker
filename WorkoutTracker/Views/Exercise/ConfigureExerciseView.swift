//
//  ConfigureExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран первоначальной настройки упражнения перед добавлением в тренировку.
//  Позволяет задать количество подходов, повторений, вес или время/дистанцию.
//  На основе этих данных генерируется начальный список сетов.
//

internal import SwiftUI

struct ConfigureExerciseView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // MARK: - Input Parameters
    
    let exerciseName: String
    let muscleGroup: String
    var exerciseType: ExerciseType = .strength
    
    /// Замыкание для возврата созданного упражнения
    var onAdd: (Exercise) -> Void
    
    // MARK: - Local State
    
    // Значения по умолчанию
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var distance = 0.0
    
    // Время разбито на минуты и секунды для удобства ввода
    @State private var minutes = 0
    @State private var seconds = 0
    
    // MARK: - Binding Adapters
    // Эти вычисляемые свойства нужны для адаптации @State (non-optional)
    // к Binding<Double?>, который требуется компонентом ClearableTextField.
    
    private var weightBinding: Binding<Double?> {
        Binding<Double?>(get: { weight }, set: { weight = $0 ?? 0 })
    }
    
    private var distanceBinding: Binding<Double?> {
        Binding<Double?>(get: { distance }, set: { distance = $0 ?? 0 })
    }
    
    private var minutesBinding: Binding<Double?> {
        Binding<Double?>(get: { Double(minutes) }, set: { minutes = Int($0 ?? 0) })
    }
    
    private var secondsBinding: Binding<Double?> {
        Binding<Double?>(get: { Double(seconds) }, set: { seconds = Int($0 ?? 0) })
    }

    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Основная секция настроек
                Section(header: Text("Configuration")) {
                    // Заголовок с именем упражнения
                    HStack {
                        Text("Exercise")
                        Spacer()
                        Text(exerciseName).bold()
                    }
                    
                    // Контент в зависимости от типа упражнения
                    switch exerciseType {
                    case .strength:
                        strengthConfig
                    case .cardio:
                        cardioConfig
                    case .duration:
                        durationConfig
                    }
                }
                
                // Кнопка действия
                Button("Add Exercise") {
                    handleSave()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Configure")
        }
    }
    
    // MARK: - View Components
    
    // 1. Силовая конфигурация
    @ViewBuilder
    private var strengthConfig: some View {
        Stepper("Sets: \(sets)", value: $sets, in: 1...20)
        Stepper("Reps: \(reps)", value: $reps, in: 1...100)
        
        HStack {
            Text("Weight (kg):")
            Spacer()
            ClearableTextField(placeholder: "kg", value: weightBinding)
                .frame(width: 80)
        }
    }
    
    // 2. Кардио конфигурация
    @ViewBuilder
    private var cardioConfig: some View {
        HStack {
            Text("Distance (km):")
            Spacer()
            ClearableTextField(placeholder: "km", value: distanceBinding)
                .frame(width: 80)
        }
        timePickerRow(label: "Duration")
    }
    
    // 3. Конфигурация на время
    @ViewBuilder
    private var durationConfig: some View {
        Stepper("Sets: \(sets)", value: $sets, in: 1...10)
        timePickerRow(label: "Time per set")
    }
    
    // Вспомогательная строка для ввода времени (Мин : Сек)
    private func timePickerRow(label: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 5) {
                ClearableTextField(placeholder: "0", value: minutesBinding)
                    .frame(width: 50)
                Text("min")
                
                ClearableTextField(placeholder: "0", value: secondsBinding)
                    .frame(width: 50)
                Text("sec")
            }
        }
    }
    
    // MARK: - Logic
    
    private func handleSave() {
        let totalSeconds = (minutes * 60) + seconds
        
        // Для кардио всегда считаем как 1 подход, для остальных берем из степпера
        let setsCount = (exerciseType == .cardio) ? 1 : sets
        
        // Генерация начальных сетов на основе введенных данных
        var generatedSets: [WorkoutSet] = []
        for i in 1...setsCount {
            generatedSets.append(WorkoutSet(
                index: i,
                weight: (exerciseType == .strength) ? weight : nil,
                reps: (exerciseType == .strength) ? reps : nil,
                distance: (exerciseType == .cardio) ? distance : nil,
                time: (totalSeconds > 0) ? totalSeconds : nil,
                isCompleted: false,
                type: .normal
            ))
        }
        
        // Создаем объект упражнения
        let newExercise = Exercise(
            name: exerciseName,
            muscleGroup: muscleGroup,
            type: exerciseType,
            sets: setsCount,
            reps: reps,
            weight: weight,
            distance: (exerciseType == .cardio) ? distance : nil,
            timeSeconds: (totalSeconds > 0) ? totalSeconds : nil,
            effort: 5,
            setsList: generatedSets // <-- Передаем сгенерированный список
        )
        
        onAdd(newExercise)
        dismiss()
    }
}

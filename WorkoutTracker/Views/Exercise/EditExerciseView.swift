//
//  EditExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран редактирования параметров уже добавленного упражнения.
//  Использует локальные @State переменные как буфер, чтобы изменения
//  применялись к основной модели только при нажатии "Save".
//

internal import SwiftUI

struct EditExerciseView: View {
    
    // MARK: - Environment & Bindings
    
    @Environment(\.dismiss) var dismiss
    
    /// Ссылка на упражнение в родительском списке (основной источник истины)
    @Binding var exercise: Exercise
    
    // MARK: - Local State (Edit Buffer)
    
    @State private var sets: Int
    @State private var reps: Int
    @State private var weight: Double
    @State private var effort: Int
    
    // Поля для кардио и времени
    @State private var distance: Double
    @State private var minutes: Int
    @State private var seconds: Int
    
    // MARK: - Init
    
    init(exercise: Binding<Exercise>) {
        self._exercise = exercise
        
        // Инициализируем локальные State значениями из переданного упражнения.
        // Это позволяет редактировать данные, не меняя оригинал до нажатия Save.
        
        // Силовые параметры
        _sets = State(initialValue: exercise.wrappedValue.sets)
        _reps = State(initialValue: exercise.wrappedValue.reps)
        _weight = State(initialValue: exercise.wrappedValue.weight)
        _effort = State(initialValue: exercise.wrappedValue.effort)
        
        // Кардио параметры
        _distance = State(initialValue: exercise.wrappedValue.distance ?? 0.0)
        
        // Время (разбиваем секунды на минуты и секунды)
        let totalSeconds = exercise.wrappedValue.timeSeconds ?? 0
        _minutes = State(initialValue: totalSeconds / 60)
        _seconds = State(initialValue: totalSeconds % 60)
    }
    
    // MARK: - Body
    
    var body: some View {
        Form {
            // 1. Основные настройки (Сеты, Вес, Время)
            configSection
            
            // 2. Настройка RPE (Усилия)
            effortSection
            
            // 3. Кнопка сохранения
            saveButton
        }
        .navigationTitle("Edit Exercise")
    }
    
    // MARK: - View Components
    
    private var configSection: some View {
        Section(header: Text("Configuration")) {
            // Заголовок
            HStack {
                Text("Exercise")
                Spacer()
                Text(exercise.name).bold()
            }
            
            // Поля в зависимости от типа
            switch exercise.type {
            case .strength:
                strengthConfig
            case .cardio:
                cardioConfig
            case .duration:
                durationConfig
            }
        }
    }
    
    @ViewBuilder
    private var strengthConfig: some View {
        Stepper("Sets: \(sets)", value: $sets, in: 1...20)
        Stepper("Reps: \(reps)", value: $reps, in: 1...100)
        HStack {
            Text("Weight (kg):")
            TextField("0", value: $weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
    
    @ViewBuilder
    private var cardioConfig: some View {
        HStack {
            Text("Distance (km):")
            TextField("0", value: $distance, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
        timePickerRow(label: "Duration")
    }
    
    @ViewBuilder
    private var durationConfig: some View {
        Stepper("Sets: \(sets)", value: $sets, in: 1...10)
        timePickerRow(label: "Time per set")
    }
    
    private var effortSection: some View {
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
    }
    
    private var saveButton: some View {
        Button("Save Changes") {
            save()
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
    }
    
    // Вспомогательная строка ввода времени
    private func timePickerRow(label: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            
            TextField("0", value: $minutes, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
            
            Text("min")
            
            TextField("0", value: $seconds, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
            
            Text("sec")
        }
    }
    
    // MARK: - Logic / Helpers
    
    private func save() {
        // Применяем локальные изменения к основной модели
        exercise.sets = (exercise.type == .cardio) ? 1 : sets
        exercise.reps = (exercise.type == .strength) ? reps : 0
        exercise.weight = (exercise.type == .strength) ? weight : 0
        exercise.effort = effort
        
        exercise.distance = (exercise.type == .cardio) ? distance : nil
        
        let totalSec = (minutes * 60) + seconds
        exercise.timeSeconds = (totalSec > 0) ? totalSec : nil
        
        dismiss()
    }
    
    private func effortColor(_ value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
}

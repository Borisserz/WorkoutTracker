//
//  EditExerciseView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Экран редактирования общих параметров упражнения (во время тренировки).
//  Ограничен редактированием уровня усилий (RPE),
//  чтобы не конфликтовать с построчным вводом веса и повторений в SetRowView.
//

internal import SwiftUI
import SwiftData

struct EditExerciseView: View {
    
    // MARK: - Environment & Bindings
    
    @Environment(\.dismiss) var dismiss
    
    /// Ссылка на упражнение в родительском списке (основной источник истины)
    @Bindable var exercise: Exercise // ДОБАВЛЕНО: @Bindable вместо @Binding
    
    // MARK: - Init
    
    init(exercise: Exercise) {
        self.exercise = exercise
    }
    
    // MARK: - Body
    
    var body: some View {
        Form {
            // 1. Основные настройки
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
        }
    }
    
    private var effortSection: some View {
        Section(header: Text("Effort (RPE)")) {
            HStack {
                Text("\(exercise.effort)/10")
                    .bold()
                    .foregroundColor(effortColor(exercise.effort))
                
                // Привязываем слайдер напрямую к свойству effort модели
                Slider(value: Binding(get: { Double(exercise.effort) }, set: { exercise.effort = Int($0) }), in: 1...10, step: 1)
                    .tint(effortColor(exercise.effort))
            }
            Text("1 = Easy, 10 = Failure")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var saveButton: some View {
        Button("Save Changes") {
            dismiss() // Изменения в @Bindable сохраняются автоматически
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
    }
    
    // MARK: - Logic / Helpers
    
    private func effortColor(_ value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
}

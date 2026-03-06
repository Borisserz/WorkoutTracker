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

struct EditExerciseView: View {
    
    // MARK: - Environment & Bindings
    
    @Environment(\.dismiss) var dismiss
    
    /// Ссылка на упражнение в родительском списке (основной источник истины)
    @Binding var exercise: Exercise
    
    // MARK: - Local State (Edit Buffer)
    
    @State private var effort: Int
    
    // MARK: - Init
    
    init(exercise: Binding<Exercise>) {
        self._exercise = exercise
        
        // Инициализируем локальные State значениями из переданного упражнения.
        _effort = State(initialValue: exercise.wrappedValue.effort)
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
    
    // MARK: - Logic / Helpers
    
    private func save() {
        // Применяем локальные изменения к основной модели
        exercise.effort = effort
        
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

//
//  ExerciseSelectionView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI

struct ExerciseSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedExercises: [Exercise]
    
    // 1. ПОДКЛЮЧАЕМ VIEWMODEL, чтобы видеть пользовательские упражнения
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    var body: some View {
        NavigationStack {
            List {
                // 2. БЕРЕМ ДАННЫЕ ИЗ viewModel.combinedCatalog, А НЕ ИЗ Exercise.catalog
                ForEach(viewModel.combinedCatalog.keys.sorted(), id: \.self) { group in
                                Section(header: Text(LocalizedStringKey(group))) { // <-- ИСПРАВЛЕНО
                        
                        // Сортируем упражнения по алфавиту
                        let exercisesInGroup = viewModel.combinedCatalog[group]?.sorted() ?? []
                        
                        ForEach(exercisesInGroup, id: \.self) { exerciseName in
                            // ВМЕСТО КНОПКИ ДЕЛАЕМ ПЕРЕХОД К НАСТРОЙКЕ
                            NavigationLink {
                                ConfigureExerciseView(exerciseName: exerciseName, muscleGroup: group) { newExercise in
                                    // Это сработает, когда в следующем окне нажмут "Add"
                                    selectedExercises.append(newExercise)
                                    dismiss() // Закрываем весь каталог
                                }
                            } label: {
                                HStack {
                                    Text(LocalizedStringKey(exerciseName))
                                    Spacer()
                                    // 3. Добавляем иконку, если упражнение свое
                                    if isCustom(name: exerciseName) {
                                        Image(systemName: "person.crop.circle")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Exercise")
            .toolbar {
                Button("Close") { dismiss() }
            }
        }
    }
    
    // Вспомогательная функция для проверки
    func isCustom(name: String) -> Bool {
        return viewModel.customExercises.contains(where: { $0.name == name })
    }
}

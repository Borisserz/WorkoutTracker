//
//  WorkoutView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    
    
    
    
    
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.workouts.isEmpty {
                    // Пустое состояние
                    VStack(spacing: 20) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("No workouts yet")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.secondary)
                        Text("Start your first workout from the Overview tab!")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    // Список тренировок
                    List {
                        // Используем binding ($workout), чтобы можно было передать его в DetailView
                        ForEach($viewModel.workouts) { $workout in
                            ZStack {
                                // Ссылка на детали (невидимая, но активная)
                                NavigationLink(destination: WorkoutDetailView(workout: $workout)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                // Внешний вид ячейки
                                WorkoutRow(workout: workout)
                            }
                            .listRowSeparator(.hidden) // Убираем стандартные линии разделители
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)) // Отступы
                        }
                        // МАГИЯ УДАЛЕНИЯ (Свайп)
                        .onDelete(perform: deleteWorkout)
                    }
                    .listStyle(.plain) // Стиль списка
                }
            }
            .navigationTitle("History")
            .toolbar {
                // КНОПКА EDIT (Сверху справа, как в будильнике)
                // Она активирует режим удаления (красные минусы)
                if !viewModel.workouts.isEmpty {
                    EditButton()
                }
            }
        }
    }
    
    // Функция удаления
    func deleteWorkout(at offsets: IndexSet) {
        // Удаляем из массива во ViewModel
        withAnimation {
            viewModel.workouts.remove(atOffsets: offsets)
        }
    }
}

// Вынесенный дизайн ячейки для чистоты кода
struct WorkoutRow: View {
    let workout: Workout
    
    // Вспомогательная функция для цвета
    func effortColor(percentage: Int) -> Color {
        if percentage > 80 { return .red }
        if percentage > 50 { return .orange }
        return .green
    }
    
    var body: some View {
        HStack {
            // Иконка
            Image(systemName: workout.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            // Текст (Название и Дата)
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Статистика справа
            VStack(alignment: .trailing, spacing: 4) {
                // Длительность
                Text("\(workout.duration) min")
                    .font(.subheadline)
                    .bold()
                
                // Усилие
                Text("Effort: \(workout.effortPercentage)%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(effortColor(percentage: workout.effortPercentage).opacity(0.2))
                    .foregroundColor(effortColor(percentage: workout.effortPercentage))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground)) // Адаптивный фон (серый/черный)
        .cornerRadius(12)
        // Тень для красоты "карточки"
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    WorkoutView()
        .environmentObject(WorkoutViewModel())
}

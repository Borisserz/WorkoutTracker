// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/WorkoutDetailHeaderView.swift
// ============================================================

internal import SwiftUI

struct WorkoutDetailHeaderView: View {
    @Bindable var workout: Workout
    var viewModel: WorkoutDetailViewModel // ✅ ДОБАВЛЕНО: Прямой доступ к живой аналитике
    
    @Environment(UnitsManager.self) var unitsManager
    
    // Быстро вычисляем количество завершенных подходов
    private var completedSetsCount: Int {
        var count = 0
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            for sub in targets {
                count += sub.setsList.filter { $0.isCompleted }.count
            }
        }
        return count
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            // 1. Верхний блок: Индикатор активности и Таймер
            if workout.isActive {
                HStack {
                    Label(LocalizedStringKey("Live Workout"), systemImage: "record.circle")
                        .foregroundStyle(Color.accentColor).bold().blinking()
                    Spacer()
                    WorkoutTimerView(startDate: workout.date)
                }
                .padding().background(Color.accentColor.opacity(0.1)).cornerRadius(12)
            } else {
                HStack {
                    Image(systemName: "flag.checkered").foregroundColor(.accentColor)
                    Text(LocalizedStringKey("Completed")).bold()
                    Spacer()
                    Text(workout.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                }
                .padding().background(Color.accentColor.opacity(0.1)).cornerRadius(12)
            }
            
            // 2. НОВЫЙ БЛОК: Динамический тоннаж и количество сетов
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("🏋️ Total Lifted"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Берем живой вес из аналитики и конвертируем под систему счисления
                    let volume = viewModel.workoutAnalytics.volume
                    let convertedVolume = unitsManager.convertFromKilograms(volume)
                    
                    Text("\(LocalizationHelper.shared.formatInteger(convertedVolume)) \(unitsManager.weightUnitString())")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                        .contentTransition(.numericText()) // 💫 Анимация прокрутки цифр
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(LocalizedStringKey("Completed Sets"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(completedSetsCount)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.accentColor)
                        .contentTransition(.numericText()) // 💫 Анимация прокрутки цифр
                }
            }
            .padding().background(Color.accentColor.opacity(0.05)).cornerRadius(10)
            // Плавная пружинная анимация при добавлении каждого сета
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.workoutAnalytics.volume)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: completedSetsCount)
        }
        .zIndex(10)
    }
}

extension View {
    func blinking() -> some View {
        self.modifier(BlinkingTextModifier())
    }
}

struct WorkoutTimerView: View {
    let startDate: Date
    
    var body: some View {
        Text(startDate, style: .timer)
            .font(.title2)
            .bold()
            .monospacedDigit()
            .foregroundColor(.primary)
    }
}

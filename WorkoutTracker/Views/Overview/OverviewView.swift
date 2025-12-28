//
//  OverviewView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI
import Charts



struct OverviewView: View {
    @State private var showAddWorkout = false
    @EnvironmentObject var viewModel: WorkoutViewModel
    @State private var navigateToNewWorkout = false
    // --- СОСТОЯНИЕ ДЛЯ ИНТЕРАКТИВНОСТИ ---
    @State private var selectedAngle: Int?
    
    // --- ЛОГИКА ГРУППИРОВКИ ДЛЯ ВОССТАНОВЛЕНИЯ ---
    struct MuscleGroupSummary {
        let name: String
        let percentage: Int
    }
    
    // Вычисляем среднее для 4-х основных групп
    var aggregatedRecovery: [MuscleGroupSummary] {
        // Карта: Главная Категория -> Список мышц из MuscleMapping (С БОЛЬШОЙ БУКВЫ, как они хранятся в recoveryStatus)
        let mapping: [String: [String]] = [
            "Chest": ["Chest"],
            "Back": ["Back", "Lower Back", "Trapezius"],
            "Arms": ["Biceps", "Triceps", "Forearms", "Shoulders"],
            "Legs": ["Legs", "Hamstrings", "Calves", "Glutes"]
        ]
        
        var result: [MuscleGroupSummary] = []
        let order = ["Chest", "Back", "Legs", "Arms"]
        
        for category in order {
            let subMuscles = mapping[category] ?? []
            // Ищем данные по этим мышцам в ViewModel
            let statuses = viewModel.recoveryStatus.filter { subMuscles.contains($0.muscleGroup) }
            
            if statuses.isEmpty {
                // Если данных нет, считаем, что мышцы свежие (100%)
                result.append(MuscleGroupSummary(name: category, percentage: 100))
            } else {
                let total = statuses.reduce(0) { $0 + $1.recoveryPercentage }
                let average = total / statuses.count
                result.append(MuscleGroupSummary(name: category, percentage: average))
            }
        }
        return result
    }

    // --- ВЫЧИСЛЕНИЯ ДЛЯ ГРАФИКОВ (ИСПРАВЛЕНО ДЛЯ СУПЕР-СЕТОВ) ---
    var muscleData: [(muscle: String, count: Int)] {
        var stats: [String: Int] = [:]
        
        for workout in viewModel.workouts {
            for exercise in workout.exercises {
                if exercise.isSuperset {
                    // Если супер-сет, берем мышцы вложенных упражнений
                    for sub in exercise.subExercises {
                        stats[sub.muscleGroup, default: 0] += 1
                    }
                } else {
                    // Если обычное упражнение
                    stats[exercise.muscleGroup, default: 0] += 1
                }
            }
        }
        // Сортируем от большего к меньшему
        return stats.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }
    
    var totalExercisesCount: Int {
        muscleData.reduce(0) { $0 + $1.count }
    }
    
    var selectedMuscleInfo: (muscle: String, count: Int)? {
        guard let selectedAngle else { return nil }
        var currentSum = 0
        for item in muscleData {
            currentSum += item.count
            if selectedAngle <= currentSum {
                return item
            }
        }
        return nil
    }
    
    // --- ТОП 5 УПРАЖНЕНИЙ (ИСПРАВЛЕНО ДЛЯ СУПЕР-СЕТОВ) ---
    var topExercises: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        // Считаем, сколько раз встречалось каждое название
        for workout in viewModel.workouts {
            for exercise in workout.exercises {
                if exercise.isSuperset {
                    // Считаем внутренние упражнения
                    for sub in exercise.subExercises {
                        counts[sub.name, default: 0] += 1
                    }
                } else {
                    counts[exercise.name, default: 0] += 1
                }
            }
        }
        
        // Сортируем и берем топ 5
        return counts.map { ($0.key, $0.value) }
                     .sorted { $0.1 > $1.1 }
                     .prefix(5)
                     .map { $0 }
    }
    
    // --- ОСНОВНОЙ BODY ---
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    recoverySection
                    chartSection
                    recentWorkoutsSection
                    topExercisesSection
                }
                .padding()
            }
            .navigationTitle("Overview")
            .navigationDestination(isPresented: $navigateToNewWorkout) {
                           if !viewModel.workouts.isEmpty {
                               WorkoutDetailView(workout: $viewModel.workouts[0])
                           }
                       }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.primary)
                }
            }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        NavigationLink(destination: WorkoutCalendarView()) {
                            Image(systemName: "calendar")
                        }
                        
                        Button {
                            showAddWorkout = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }.sheet(isPresented: $showSettings) { // <--- ОТКРЫТИЕ НАСТРОЕК
                SettingsView()
            }
            .sheet(isPresented: $showAddWorkout) {
                            AddWorkoutView(workouts: $viewModel.workouts, onWorkoutCreated: {
                                // Когда тренировка создана, включаем флаг перехода
                                navigateToNewWorkout = true
                            })
                        }
                    }
                }
    
    // --- ВЫНЕСЕННЫЕ БЛОКИ ---
    
    // 1. Recovery
    private var recoverySection: some View {
           NavigationLink(destination: DetailedRecoveryView()) {
               VStack(alignment: .leading, spacing: 10) {
                   HStack {
                       Text("Muscle Recovery")
                           .font(.headline)
                           .foregroundColor(.primary)
                       Spacer()
                       Text("See details")
                           .font(.caption)
                           .foregroundColor(.blue)
                       Image(systemName: "chevron.right")
                           .font(.caption)
                           .foregroundColor(.gray)
                   }
                   
                   Divider()
                   
                   if viewModel.workouts.isEmpty {
                        Text("Start training to see stats.")
                           .foregroundColor(.secondary)
                           .padding(.vertical, 5)
                   } else {
                       ForEach(aggregatedRecovery, id: \.name) { group in
                           VStack(spacing: 5) {
                               HStack {
                                   Text(LocalizedStringKey(group.name))
                                       .fontWeight(.medium)
                                       .foregroundColor(.primary)
                                   Spacer()
                                   Text("\(group.percentage)%")
                                       .font(.subheadline)
                                       .bold()
                                       .foregroundColor(recoveryColor(group.percentage))
                               }
                               ProgressView(value: Double(group.percentage), total: 100)
                                   .tint(recoveryColor(group.percentage))
                           }
                       }
                   }
               }
               .padding()
               .background(Color.gray.opacity(0.1))
               .cornerRadius(12)
           }
           .buttonStyle(PlainButtonStyle())
       }
    
    // 2. Chart
    private var chartSection: some View {
        VStack(alignment: .leading) {
            Text("Muscles Worked")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if muscleData.isEmpty {
                Text("No workouts yet")
                    .padding().frame(maxWidth: .infinity).foregroundColor(.secondary)
            } else {
                Chart(muscleData, id: \.muscle) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .cornerRadius(5)
                    .foregroundStyle(by: .value("Muscle", item.muscle))
                    .opacity(selectedMuscleInfo == nil || selectedMuscleInfo?.muscle == item.muscle ? 1.0 : 0.3)
                }
                .frame(height: 250)
                .chartAngleSelection(value: $selectedAngle)
                .chartBackground { proxy in
                    GeometryReader { geometry in
                        VStack {
                            if let selected = selectedMuscleInfo {
                                Text(LocalizedStringKey(selected.muscle))
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                Text("\(selected.count) sets")
                                    .font(.title2).bold()
                                    .foregroundColor(.blue)
                            } else {
                                Text(LocalizedStringKey("Total"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(totalExercisesCount)")
                                    .font(.title).bold()
                                    .foregroundColor(.primary)
                            }
                        }
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    @State private var showSettings = false // <--- НОВОЕ СОСТОЯНИЕ
    // 3. Recent Workouts
    private var recentWorkoutsSection: some View {
        VStack {
            HStack {
                Text("Recent Workouts").font(.title2).bold()
                Spacer()
                NavigationLink {
                    WorkoutView()
                } label: {
                    Text("See all").font(.subheadline)
                }
            }
            
            if viewModel.workouts.isEmpty {
                Text("No workouts yet. Tap + to start!").foregroundColor(.secondary).padding()
            } else {
                let count = min(viewModel.workouts.count, 3)
                ForEach(0..<count, id: \.self) { index in
                    let workoutBinding = $viewModel.workouts[index]
                    NavigationLink(destination: WorkoutDetailView(workout: workoutBinding)) {
                        recentWorkoutRow(workout: viewModel.workouts[index])
                    }
                }
            }
        }
    }
    
    // 4. Top Exercises
    private var topExercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !topExercises.isEmpty {
                Text("Top 5 Exercises")
                    .font(.title2)
                    .bold()
                    .padding(.top, 10)
                
                ForEach(topExercises, id: \.name) { item in
                    NavigationLink(destination: ExerciseHistoryView(exerciseName: item.name, allWorkouts: viewModel.workouts)) {
                        HStack {
                            rankIcon(for: item.name)
                            
                            Text(LocalizedStringKey(item.name))
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(item.count) times")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func rankIcon(for name: String) -> some View {
        if let index = topExercises.firstIndex(where: { $0.name == name }) {
            let rank = index + 1
            ZStack {
                Circle()
                    .fill(rank == 1 ? Color.yellow : (rank == 2 ? Color.gray : (rank == 3 ? Color.brown : Color.blue.opacity(0.1))))
                    .frame(width: 30, height: 30)
                
                Text("\(rank)")
                    .font(.caption)
                    .bold()
                    .foregroundColor(rank <= 3 ? .white : .blue)
            }
            .padding(.trailing, 5)
        }
    }
    
    private func recentWorkoutRow(workout: Workout) -> some View {
        HStack {
            Image(systemName: workout.icon)
                .font(.title2).padding(10)
                .background(Color.blue.opacity(0.1)).clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(workout.title).font(.headline).foregroundColor(.primary)
                Text(workout.date, style: .date).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(workout.duration) min").font(.subheadline).bold().foregroundColor(.primary)
                Text("Effort: \(workout.effortPercentage)%")
                    .font(.caption)
                    .foregroundColor(workout.effortPercentage > 80 ? .red : (workout.effortPercentage > 50 ? .orange : .green))
            }
        }
        .padding().background(Color.white).cornerRadius(10)
        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
    }
    
    func recoveryColor(_ percentage: Int) -> Color {
        if percentage < 50 { return .red }
        if percentage < 80 { return .orange }
        return .green
    }
}

#Preview {
    OverviewView().environmentObject(WorkoutViewModel())
}

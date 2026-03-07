//
//  OverviewView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI
import Charts

struct OverviewView: View {
    
    // MARK: - Models
    
    struct MuscleGroupSummary {
        let name: String
        let percentage: Int
    }
    
    // MARK: - Environment & State
    @EnvironmentObject var tutorialManager: TutorialManager
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // Навигация и модальные окна
    @State private var showAddWorkout = false
    @State private var showSettings = false
    @State private var showMuscleColorSettings = false
    @State private var navigateToNewWorkout = false
    @State private var navigateToExercises = false
    
    // Интерактивность графика
    @State private var selectedAngle: Int?
    
    // Менеджер цветов
    @StateObject private var colorManager = MuscleColorManager.shared
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                
                // --- СЛОЙ 1: ОСНОВНОЙ КОНТЕНТ ---
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // 1. ПУСТОЕ СОСТОЯНИЕ (БОЛЬШАЯ КНОПКА)
                        if viewModel.workouts.isEmpty {
                            VStack(spacing: 15) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue.opacity(0.8))
                                
                                Text(LocalizedStringKey("Welcome to WorkoutTracker!"))
                                    .font(.title3).bold()
                                
                                Text(LocalizedStringKey("Your journey starts here. Create your first workout to begin tracking."))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button {
                                    showAddWorkout = true
                                    // Логика перехода на следующий шаг туториала
                                    if tutorialManager.currentStep == .tapPlus {
                                        tutorialManager.nextStep()
                                    }
                                } label: {
                                    Text(LocalizedStringKey("Start First Workout"))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                                .spotlight(
                                    step: .tapPlus, // Это самый первый шаг (0)
                                    manager: tutorialManager,
                                    text: "Tap here to create your first workout!",
                                    alignment: .top, // Текст СВЕРХУ кнопки
                                    yOffset: -10
                                )
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.top, 10)
                        }
                        
                        // 2. Блок восстановления
                        recoverySection
                        
                        // 3. График мышц (Скрываем если пусто)
                        if !viewModel.workouts.isEmpty {
                            chartSection
                        }
                        
                        // 4. Топ упражнений
                        if !viewModel.workouts.isEmpty {
                            topExercisesSection
                        }
                    }
                    .padding()
                }
                
                // --- СЛОЙ 2: ФАНТОМНАЯ КНОПКА ДЛЯ ТУЛБАРА ---
                // Показываем её ТОЛЬКО если есть тренировки
                if !viewModel.workouts.isEmpty {
                    Color.white.opacity(0.01) // Почти прозрачный
                        .frame(width: 50, height: 50)
                        .contentShape(Rectangle())
                        .offset(x: -10, y: 0)
                        .spotlight(
                            step: .tapPlus,
                            manager: tutorialManager,
                            text: "Tap + to add a new workout",
                            alignment: .bottom
                        )
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(LocalizedStringKey("Overview"))
            
            // --- НАВИГАЦИЯ ---
            .navigationDestination(isPresented: $navigateToNewWorkout) {
                if let firstWorkout = viewModel.workouts.first {
                    // ИЗМЕНЕНИЕ: Передаем ссылку на объект, а не Binding ($)
                    WorkoutDetailView(workout: firstWorkout)
                }
            }
            .navigationDestination(isPresented: $navigateToExercises) {
                ExerciseView()
            }
            .toolbar {
                // Левая кнопка (Настройки)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
                
                // Правые кнопки (Календарь)
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: WorkoutCalendarView()) {
                        Image(systemName: "calendar")
                    }
                }
            }
            // Модальные окна
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showAddWorkout) {
                // ИЗМЕНЕНИЕ: Убран Binding workouts: $viewModel.workouts
                AddWorkoutView(onWorkoutCreated: {
                    navigateToNewWorkout = true
                })
            }
            .sheet(isPresented: $showMuscleColorSettings) {
                MuscleColorSettingsView()
            }
        }
    }
    
    // MARK: - Logic & Components
    
    private var aggregatedRecovery: [MuscleGroupSummary] {
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
            let statuses = viewModel.recoveryStatus.filter { subMuscles.contains($0.muscleGroup) }
            
            if statuses.isEmpty {
                result.append(MuscleGroupSummary(name: category, percentage: 100))
            } else {
                let total = statuses.reduce(0) { $0 + $1.recoveryPercentage }
                let average = total / statuses.count
                result.append(MuscleGroupSummary(name: category, percentage: average))
            }
        }
        return result
    }

    private var muscleData: [(muscle: String, count: Int)] {
        var stats: [String: Int] = [:]
        
        for workout in viewModel.workouts {
            for exercise in workout.exercises {
                func shouldSkip(_ ex: Exercise) -> Bool {
                    return ex.type == .cardio || ex.type == .duration || ex.muscleGroup == "Cardio"
                }
                
                if exercise.isSuperset {
                    for sub in exercise.subExercises {
                        if shouldSkip(sub) { continue }
                        stats[sub.muscleGroup, default: 0] += 1
                    }
                } else {
                    if shouldSkip(exercise) { continue }
                    stats[exercise.muscleGroup, default: 0] += 1
                }
            }
        }
        // Фильтруем элементы с count = 0, чтобы они не попадали в легенду, но не отображались на диаграмме
        return stats.map { ($0.key, $0.value) }
            .filter { $0.count > 0 }
            .sorted { $0.1 > $1.1 }
    }
    
    private var totalExercisesCount: Int {
        muscleData.reduce(0) { $0 + $1.count }
    }
    
    private var selectedMuscleInfo: (muscle: String, count: Int)? {
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
    
    var topExercises: [(name: String, count: Int)] {
          var counts: [String: Int] = [:]
          for workout in viewModel.workouts {
              for exercise in workout.exercises {
                  if exercise.isSuperset {
                      for sub in exercise.subExercises {
                          counts[sub.name, default: 0] += 1
                      }
                  } else {
                      counts[exercise.name, default: 0] += 1
                  }
              }
          }
          return counts
              .sorted { (first, second) -> Bool in
                  if first.value != second.value {
                      return first.value > second.value
                  }
                  return first.key < second.key
              }
              .prefix(5)
              .map { (name: $0.key, count: $0.value) }
      }
    
    // --- Subviews ---
    
    private var recoverySection: some View {
            NavigationLink(destination: DetailedRecoveryView()) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(LocalizedStringKey("Muscle Recovery")).font(.headline).foregroundColor(.primary)
                        Spacer()
                        Text(LocalizedStringKey("See details")).font(.caption).foregroundColor(.blue)
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                    }
                    Divider()
                    if viewModel.workouts.isEmpty {
                        Text(LocalizedStringKey("Complete a workout to see data")).font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(aggregatedRecovery, id: \.name) { group in
                            VStack(spacing: 5) {
                                HStack {
                                    Text(LocalizedStringKey(group.name)).fontWeight(.medium).foregroundColor(.primary)
                                    Spacer()
                                    Text("\(group.percentage)%").font(.subheadline).bold().foregroundColor(recoveryColor(group.percentage))
                                }
                                ProgressView(value: Double(group.percentage), total: 100)
                                    .tint(recoveryColor(group.percentage))
                            }
                        }
                    }
                }
                .padding().background(Color.gray.opacity(0.1)).cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded {
                if tutorialManager.currentStep == .recoveryCheck {
                    tutorialManager.nextStep()
                }
            })
            .spotlight(
                step: .recoveryCheck,
                manager: tutorialManager,
                text: "Check your Muscle Recovery status here.",
                alignment: .top,
                yOffset: -10
            )
        }
    
    private var chartSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(LocalizedStringKey("Muscles Worked")).font(.headline).foregroundColor(.secondary)
                Spacer()
                Button {
                    showMuscleColorSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if muscleData.isEmpty {
                Text(LocalizedStringKey("No workouts yet")).padding().frame(maxWidth: .infinity).foregroundColor(.secondary)
            } else {
                Chart(muscleData, id: \.muscle) { item in
                    SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.6), angularInset: 2)
                        .cornerRadius(5)
                        .foregroundStyle(by: .value("Muscle", item.muscle))
                        .opacity(selectedMuscleInfo == nil || selectedMuscleInfo?.muscle == item.muscle ? 1.0 : 0.3)
                }
                .chartForegroundStyleScale(domain: muscleData.map { $0.muscle }, range: muscleData.map { colorManager.getColor(for: $0.muscle) })
                .frame(height: 250)
                .chartAngleSelection(value: $selectedAngle)
                .chartBackground { proxy in
                    GeometryReader { geometry in
                        VStack {
                            if let selected = selectedMuscleInfo {
                                Text(LocalizedStringKey(selected.muscle)).font(.headline).multilineTextAlignment(.center)
                                Text(LocalizedStringKey("\(selected.count) sets")).font(.title2).bold().foregroundColor(.blue)
                            } else {
                                Text(LocalizedStringKey("Total")).font(.caption).foregroundColor(.secondary)
                                Text("\(totalExercisesCount)").font(.title).bold().foregroundColor(.primary)
                            }
                        }
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
            }
        }
        .padding().background(Color.gray.opacity(0.1)).cornerRadius(12)
        .spotlight(
            step: .highlightChart,
            manager: tutorialManager,
            text: "See which muscles you train the most.",
            alignment: .top,
            yOffset: -10
        )
        .onTapGesture {
            if tutorialManager.currentStep == .highlightChart {
                // Если нужно пропустить шаг Chart -> Body
                // tutorialManager.nextStep()
            }
        }
    }
    
    private var topExercisesSection: some View {
         VStack(alignment: .leading, spacing: 10) {
             if !topExercises.isEmpty {
                 HStack {
                     Text(LocalizedStringKey("Exercises")).font(.title2).bold()
                     Spacer()
                     Button {
                         navigateToExercises = true
                     } label: {
                         Text(LocalizedStringKey("See all")).font(.subheadline).foregroundColor(.blue)
                     }
                 }
                 .padding(.top, 10)
                 
                 ForEach(Array(topExercises.enumerated()), id: \.element.name) { index, item in
                     NavigationLink(destination: ExerciseHistoryView(exerciseName: item.name, allWorkouts: viewModel.workouts)) {
                         HStack {
                             rankIcon(rank: index + 1)
                             Text(LocalizedStringKey(item.name)).font(.headline).foregroundColor(.primary)
                             Spacer()
                             Text("\(item.count) times").font(.subheadline).foregroundColor(.secondary)
                             Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                         }
                         .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(10).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                     }
                 }
             }
         }
     }
    
    @ViewBuilder
    private func rankIcon(rank: Int) -> some View {
        ZStack {
            Circle().fill(rank == 1 ? Color.yellow : rank == 2 ? Color.gray : rank == 3 ? Color.brown : Color.blue.opacity(0.1)).frame(width: 30, height: 30)
            Text("\(rank)").font(.caption).bold().foregroundColor(rank <= 3 ? .white : .blue)
        }.padding(.trailing, 5)
    }
    
    private func recoveryColor(_ percentage: Int) -> Color {
        if percentage < 50 { return .red }
        if percentage < 80 { return .orange }
        return .green
    }
}


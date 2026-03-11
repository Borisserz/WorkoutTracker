//
//  OverviewView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI
import SwiftData
import Charts

struct OverviewView: View {
    
    // MARK: - Environment & State
    @Environment(\.modelContext) private var context
    @EnvironmentObject var tutorialManager: TutorialManager
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // ОПТИМИЗАЦИЯ: Загружаем строго ОДНУ тренировку для проверки на пустоту.
    // Это полностью устраняет лаги при переходе на этот экран.
    @Query private var recentWorkouts: [Workout]
    
    // Навигация и модальные окна
    @State private var showAddWorkout = false
    @State private var showSettings = false
    @State private var showMuscleColorSettings = false
    @State private var navigateToNewWorkout = false
    @State private var navigateToExercises = false
    @State private var navigateToDetailedRecovery = false // Программная навигация к восстановлению
    
    // Интерактивность графика и анимации
    @State private var selectedAngle: Int?
    @State private var isPulsing = false // Добавлено для пульсирующей кнопки
    
    // Менеджер цветов
    @StateObject private var colorManager = MuscleColorManager.shared
    
    init() {
        var desc = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        desc.fetchLimit = 1
        _recentWorkouts = Query(desc)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                
                // --- СЛОЙ 1: ОСНОВНОЙ КОНТЕНТ ---
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // 1. ПУСТОЕ СОСТОЯНИЕ
                        if recentWorkouts.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 80))
                                    .foregroundColor(.blue.opacity(0.8))
                                
                                Text(LocalizedStringKey("Welcome to WorkoutTracker!"))
                                    .font(.title2).bold()
                                
                                Text(LocalizedStringKey("Your journey starts here. Create your first workout to begin tracking."))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button {
                                    showAddWorkout = true
                                    if tutorialManager.currentStep == .tapPlus {
                                        tutorialManager.nextStep()
                                    }
                                } label: {
                                    Text(LocalizedStringKey("Start Your First Workout"))
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.white)
                                        .padding(.vertical, 20)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .cornerRadius(16)
                                        .shadow(color: .blue.opacity(0.6), radius: isPulsing ? 15 : 5, x: 0, y: isPulsing ? 8 : 2)
                                        .scaleEffect(isPulsing ? 1.03 : 0.97)
                                        // ИСПРАВЛЕНИЕ: Анимация только для визуала кнопки, а не её позиции
                                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                                }
                                .padding(.top, 10)
                                .onAppear {
                                    // ИСПРАВЛЕНИЕ: Минимальная задержка, чтобы UI успел отрендерить фрейм до старта анимации
                                    Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 100_000_000)
                                        isPulsing = true
                                    }
                                }
                                .spotlight(
                                    step: .tapPlus,
                                    manager: tutorialManager,
                                    text: "Tap here to create your first workout!",
                                    alignment: .top,
                                    yOffset: -10
                                )
                            }
                            .padding(24)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(20)
                            .padding(.top, 10)
                        }
                        
                        // 2. График мышц (перенесен выше)
                        if !recentWorkouts.isEmpty {
                            chartSection
                        }
                        
                        // 3. Блок восстановления
                        recoverySection
                        
                        // 4. Топ упражнений
                        if !recentWorkouts.isEmpty {
                            topExercisesSection
                        }
                    }
                    .padding()
                }
                
                // --- СЛОЙ 2: ФАНТОМНАЯ КНОПКА ДЛЯ ТУЛБАРА ---
                if !recentWorkouts.isEmpty {
                    Color.white.opacity(0.01)
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
            .onAppear {
                // Инициируем обновление кэша (выполняется в фоне)
                viewModel.refreshAllCaches(container: context.container)
            }
            // --- НАВИГАЦИЯ ---
            .navigationDestination(isPresented: $navigateToNewWorkout) {
                if let firstWorkout = recentWorkouts.first {
                    WorkoutDetailView(workout: firstWorkout)
                }
            }
            .navigationDestination(isPresented: $navigateToExercises) {
                ExerciseView()
            }
            .navigationDestination(isPresented: $navigateToDetailedRecovery) {
                DetailedRecoveryView()
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
                    NavigationLink(destination: WorkoutCalendarView()) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showAddWorkout) {
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
    
    private var recoveryDict: [String: Int] {
        var dict = [String: Int]()
        for status in viewModel.recoveryStatus {
            let slug = mapToSlug(status.muscleGroup)
            dict[slug] = status.recoveryPercentage
        }
        return dict
    }
    
    // Преобразуем названия из ViewModel в технические slugs, которые понимает BodyHeatmapView
    private func mapToSlug(_ name: String) -> String {
        switch name {
        case "Chest": return "chest"
        case "Back", "Upper Back": return "upper-back"
        case "Lats": return "lats"
        case "Traps", "Trapezius": return "trapezius"
        case "Lower Back": return "lower-back"
        case "Shoulders", "Shoulders (Delts)": return "deltoids"
        case "Biceps": return "biceps"
        case "Triceps": return "triceps"
        case "Forearms": return "forearm"
        case "Abs", "Core": return "abs"
        case "Obliques": return "obliques"
        case "Legs", "Quads", "Quadriceps": return "quadriceps"
        case "Hamstrings": return "hamstring"
        case "Glutes", "Gluteal": return "gluteal"
        case "Calves": return "calves"
        default: return name.lowercased().replacingOccurrences(of: " ", with: "-")
        }
    }
    
    private var selectedMuscleInfo: (muscle: String, count: Int)? {
        guard let selectedAngle else { return nil }
        var currentSum = 0
        for item in viewModel.dashboardMuscleData {
            currentSum += item.count
            if selectedAngle <= currentSum {
                return item
            }
        }
        return nil
    }
    
    // --- Subviews ---
    
    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Заголовок работает как кнопка "Перейти"
            Button {
                navigateToDetailedRecovery = true
            } label: {
                HStack {
                    Text(LocalizedStringKey("Muscle Recovery"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(LocalizedStringKey("See details"))
                        .font(.caption)
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded {
                if tutorialManager.currentStep == .recoveryCheck {
                    tutorialManager.nextStep()
                }
            })
            
            Divider()
            
            if recentWorkouts.isEmpty {
                Text(LocalizedStringKey("Complete a workout to see data"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                BodyHeatmapView(muscleIntensities: recoveryDict, isRecoveryMode: true)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
            if viewModel.dashboardMuscleData.isEmpty {
                Text(LocalizedStringKey("No workouts yet")).padding().frame(maxWidth: .infinity).foregroundColor(.secondary)
            } else {
                Chart(viewModel.dashboardMuscleData, id: \.muscle) { item in
                    SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.6), angularInset: 2)
                        .cornerRadius(5)
                        .foregroundStyle(by: .value("Muscle", item.muscle))
                        .opacity(selectedMuscleInfo == nil || selectedMuscleInfo?.muscle == item.muscle ? 1.0 : 0.3)
                }
                .chartForegroundStyleScale(domain: viewModel.dashboardMuscleData.map { $0.muscle }, range: viewModel.dashboardMuscleData.map { colorManager.getColor(for: $0.muscle) })
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
                                Text("\(viewModel.dashboardTotalExercises)").font(.title).bold().foregroundColor(.primary)
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
    }
    
    private var topExercisesSection: some View {
         VStack(alignment: .leading, spacing: 10) {
             if !viewModel.dashboardTopExercises.isEmpty {
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
                 
                 ForEach(Array(viewModel.dashboardTopExercises.enumerated()), id: \.element.name) { index, item in
                     NavigationLink(destination: ExerciseHistoryView(exerciseName: item.name)) {
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
}


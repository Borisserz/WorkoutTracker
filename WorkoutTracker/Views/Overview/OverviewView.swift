//
//  OverviewView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI
import SwiftData
import Charts
import ActivityKit

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
    
    // Новые стейты для Профиля и превью тренировки
    @State private var showProfile = false
    @State private var generatedFreshWorkout: GeneratedWorkout?
    
    // Интерактивность графика и анимации
    @State private var selectedChartMuscle: String? = nil
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
                                                                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                                                                }
                                                                .padding(.top, 10)
                                                                .onAppear {
                                                                    Task { @MainActor in
                                                                        try? await Task.sleep(nanoseconds: 100_000_000)
                                                                        isPulsing = true
                                                                    }
                                                                }
                                                                .onDisappear {
                                                                    isPulsing = false
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
                        
                        // 3.5 Умный генератор тренировки
                        if !recentWorkouts.isEmpty {
                            generateFreshWorkoutBanner
                        }
                        
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
                viewModel.refreshAllCaches()
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
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(viewModel.progressManager)
            }
            .sheet(item: $generatedFreshWorkout) { generated in
                FreshWorkoutPreviewSheet(generatedWorkout: generated) {
                    startGeneratedWorkout(generated)
                }
            }
        }
    }
    
    // MARK: - Logic & Components
    
    private var recoveryDict: [String: Int] {
        var dict = [String: Int]()
        for status in viewModel.recoveryStatus {
            dict[status.muscleGroup] = status.recoveryPercentage // Already a slug now
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
    
    private var selectedMuscleInfo: MuscleCountDTO? {
            guard let selectedChartMuscle else { return nil }
            return viewModel.dashboardMuscleData.first(where: { $0.muscle == selectedChartMuscle })
        }
    
    // MARK: - Smart Workout Generator
    
    private var generateFreshWorkoutBanner: some View {
        Button(action: generateFreshWorkout) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Fresh Muscle Workout"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(LocalizedStringKey("Generate a routine for fully recovered muscles"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func generateFreshWorkout() {
        // 1. Ищем мышцы, восстановившиеся на >= 90%
        let freshMuscles = viewModel.recoveryStatus
            .filter { $0.recoveryPercentage >= 90 }
            .map { $0.muscleGroup }
        
        guard !freshMuscles.isEmpty else {
            viewModel.showError(
                title: String(localized: "Too Tired!"),
                message: String(localized: "You don't have enough fully recovered muscles. Take a rest day or do light cardio!")
            )
            return
        }
        
        // 2. Берем 2 случайные свежие мышцы
        let selectedMuscles = Array(freshMuscles.shuffled().prefix(2))
        var generatedExercises: [Exercise] = []
        
        // 3. Подбираем упражнения
        for muscle in selectedMuscles {
            let catalogKey = mapRecoveryNameToCatalogKey(muscle)
            if let availableExercises = Exercise.catalog[catalogKey] {
                // Берем 2 случайных упражнения на эту мышечную группу
                let pickedNames = Array(availableExercises.shuffled().prefix(2))
                
                for name in pickedNames {
                    // Создаем базовую болванку: 3 сета, 10 повторений, без веса
                    let newEx = Exercise(
                        name: name,
                        muscleGroup: catalogKey,
                        type: .strength,
                        sets: 3,
                        reps: 10,
                        weight: 0.0,
                        effort: 5
                    )
                    generatedExercises.append(newEx)
                }
            }
        }
        
        guard !generatedExercises.isEmpty else { return }
        
        // 4. Формируем тренировку и показываем шторку превью (Без сохранения в БД)
        let workoutName = "Fresh: " + selectedMuscles.joined(separator: " & ")
        generatedFreshWorkout = GeneratedWorkout(title: workoutName, exercises: generatedExercises)
    }
    
    // Запуск сгенерированной тренировки (вызывается из шторки)
    private func startGeneratedWorkout(_ generated: GeneratedWorkout) {
        let newWorkout = Workout(
            title: generated.title,
            date: Date(),
            icon: "bolt.fill",
            exercises: generated.exercises
        )
        
        // 5. Сохраняем в SwiftData и запускаем Live Activity
        context.insert(newWorkout)
        try? context.save()
        
        let attributes = WorkoutActivityAttributes(workoutTitle: generated.title)
        let state = WorkoutActivityAttributes.ContentState(startTime: Date())
        _ = try? Activity<WorkoutActivityAttributes>.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            navigateToNewWorkout = true
        }
    }
    
    /// Маппинг красивых названий с экрана Recovery в ключи каталога упражнений
    private func mapRecoveryNameToCatalogKey(_ name: String) -> String {
        switch name {
        case "Chest": return "Chest"
        case "Back", "Lower Back", "Lats", "Traps": return "Back"
        case "Shoulders", "Deltoids": return "Shoulders"
        case "Biceps", "Triceps", "Forearms", "Arms": return "Arms"
        case "Abs", "Core", "Obliques": return "Core"
        case "Legs", "Glutes", "Hamstrings", "Quads", "Calves": return "Legs"
        default: return "Other"
        }
    }
    
    // --- Subviews ---
    

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                // Оставляем только 2D версию, убрав Picker переключения
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
            VStack(alignment: .leading, spacing: 16) {
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
                    
                    // 1. САМ ГРАФИК
                    Chart(viewModel.dashboardMuscleData, id: \.muscle) { item in
                        SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.6), angularInset: 2)
                            .cornerRadius(5)
                            .foregroundStyle(colorManager.getColor(for: item.muscle))
                            .opacity(selectedChartMuscle == nil || selectedChartMuscle == item.muscle ? 1.0 : 0.3)
                    }
                    .frame(height: 220)
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
                    
                    // 2. ЛЕГЕНДА (ЦВЕТНЫЕ ТОЧКИ + НАЗВАНИЯ)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)], spacing: 12) {
                        ForEach(viewModel.dashboardMuscleData, id: \.muscle) { item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(colorManager.getColor(for: item.muscle))
                                    .frame(width: 10, height: 10)
                                    .opacity(selectedChartMuscle == nil || selectedChartMuscle == item.muscle ? 1.0 : 0.3)
                                
                                Text(LocalizedStringKey(item.muscle))
                                    .font(.caption)
                                    .fontWeight(selectedChartMuscle == item.muscle ? .bold : .regular)
                                    .foregroundColor(selectedChartMuscle == item.muscle ? .primary : .secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            // Снимаем или ставим выделение по нажатию прямо на легенду!
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedChartMuscle == item.muscle {
                                        selectedChartMuscle = nil // Снять выделение
                                    } else {
                                        selectedChartMuscle = item.muscle // Выделить
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 4)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
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

// MARK: - Fresh Workout Preview Models & Views

struct GeneratedWorkout: Identifiable {
    let id = UUID()
    let title: String
    let exercises: [Exercise]
}

struct FreshWorkoutPreviewSheet: View {
    let generatedWorkout: GeneratedWorkout
    let onStart: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(generatedWorkout.exercises) { ex in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ex.name).font(.headline)
                            Text(ex.muscleGroup)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(ex.setsCount) sets")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Ready to Train"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    onStart()
                } label: {
                    Text(LocalizedStringKey("Start Workout"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                .padding()
                .background(Color(UIColor.systemBackground).shadow(color: .black.opacity(0.1), radius: 5, y: -5))
            }
        }
    }
}

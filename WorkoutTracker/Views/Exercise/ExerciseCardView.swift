//
//  ExerciseCardView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Карточка упражнения внутри активной тренировки.
//  Отображает список сетов, позволяет вводить данные,
//  добавлять/удалять сеты и завершать упражнение.
//

internal import SwiftUI

struct ExerciseCardView: View {
    
    // MARK: - Environment & Bindings
    @EnvironmentObject var tutorialManager: TutorialManager
    @Binding var exercise: Exercise
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // MARK: - Properties
    
    let currentWorkoutId: UUID
    var onDelete: () -> Void
    var onSwap: (() -> Void)? = nil
    var isEmbeddedInSuperset: Bool = false // Флаг: скрывать кнопку Finish, если это часть суперсета
    var isWorkoutCompleted: Bool = false // Флаг завершения тренировки
    
    // MARK: - Local State
    
    @State private var showEffortSheet = false
    @State private var showPRCelebration = false
    @State private var isExpanded: Bool // Состояние раскрытия/сворачивания упражнения
    
    // MARK: - Initializer
    
    init(
        exercise: Binding<Exercise>,
        currentWorkoutId: UUID,
        onDelete: @escaping () -> Void,
        onSwap: (() -> Void)? = nil,
        isEmbeddedInSuperset: Bool = false,
        isWorkoutCompleted: Bool = false,
        initialExpanded: Bool = true
    ) {
        self._exercise = exercise
        self.currentWorkoutId = currentWorkoutId
        self.onDelete = onDelete
        self.onSwap = onSwap
        self.isEmbeddedInSuperset = isEmbeddedInSuperset
        self.isWorkoutCompleted = isWorkoutCompleted
        self._isExpanded = State(initialValue: initialExpanded)
    }
    
    // MARK: - Body
    
    var body: some View {
        // Получаем данные о прошлой тренировке для "призрачного текста" (Ghost Text)
        let lastExerciseData = viewModel.getLastPerformance(for: exercise.name, currentWorkoutId: currentWorkoutId)
        
        ZStack {
            // Основной контент
            VStack(alignment: .leading, spacing: 0) {
                
                // 1. Заголовок (Имя, Иконка, Меню)
                headerSection
                
                // 2. Содержимое (раскрывается/сворачивается)
                if isExpanded {
                    // 2.1. Шапка таблицы (Set, kg/Reps, Check)
                    columnHeadersSection
                    
                    // 2.2. Список сетов
                    // Оставляем цикл здесь, так как он зависит от lastExerciseData
                    ForEach($exercise.setsList.indices, id: \.self) { index in
                        let isLast = index == exercise.setsList.count - 1
                        
                        // Ищем данные этого же сета из прошлой тренировки
                        let prevSet: WorkoutSet? = (lastExerciseData != nil && index < lastExerciseData!.setsList.count)
                        ? lastExerciseData!.setsList[index]
                        : nil
                        
                        SetRowView(
                            set: $exercise.setsList[index],
                            exerciseType: exercise.type,
                            isLastSet: isLast,
                            isExerciseCompleted: exercise.isCompleted,
                            isWorkoutCompleted: isWorkoutCompleted,
                            onCheck: { shouldStartTimer in
                                if shouldStartTimer { viewModel.startRestTimer() }
                            },
                            prevWeight: prevSet?.weight,
                            prevReps: prevSet?.reps,
                            prevDist: prevSet?.distance,
                            prevTime: prevSet?.time
                        )
                        .swipeActions(edge: .trailing) {
                            if !exercise.isCompleted && !isWorkoutCompleted {
                                Button(role: .destructive) {
                                    removeSet(at: index)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    
                    // 2.3. Кнопки (Add Set, Finish)
                    actionButtonsSection
                } else {
                    // Краткая информация когда свернуто
                    collapsedInfoSection
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            // Оверлей рекорда (PR)
            if showPRCelebration {
                recordOverlay
            }
        }
        // Модификаторы
        .sheet(isPresented: $showEffortSheet) {
            EffortInputView(effort: $exercise.effort)
        }
        .blur(radius: showPRCelebration ? 5 : 0)
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack {
            // Иконка "бутерброда" для раскрытия/сворачивания
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.gray)
                .font(.caption)
                .frame(width: 20, height: 20)
            
            NavigationLink(destination: ExerciseHistoryView(exerciseName: exercise.name, allWorkouts: viewModel.workouts)) {
                HStack {
                    Image(systemName: getIcon())
                        .foregroundColor(getColor())
                        .font(.caption)
                    
                    Text(LocalizedStringKey(exercise.name))
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
            .highPriorityGesture(TapGesture().onEnded { })
            
            Spacer()
            
            // Информация о количестве сетов (показывается всегда)
            Text("\(exercise.setsList.count) sets")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Menu {
                // Опция замены упражнения
                if let onSwap = onSwap {
                    Button(action: onSwap) {
                        Label("Swap Exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("Remove Exercise", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(10)
            }
            .highPriorityGesture(TapGesture().onEnded { })
        }
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            // Раскрытие/сворачивание при нажатии на заголовок
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var columnHeadersSection: some View {
        HStack(spacing: 8) {
            Text("Set")
                .font(.caption2)
                .frame(width: 25)
                .foregroundColor(.secondary)
            
            switch exercise.type {
            case .strength:
                Text("kg").font(.caption2).frame(width: 100).foregroundColor(.secondary)
                Text("Reps").font(.caption2).frame(width: 100).foregroundColor(.secondary)
            case .cardio:
                Text("km").font(.caption2).frame(width: 100).foregroundColor(.secondary)
                Spacer()
                Text("Time").font(.caption2).frame(width: 100).foregroundColor(.secondary)
            case .duration:
                Text("Time").font(.caption2).frame(width: 100).foregroundColor(.secondary)
            }
            
            Text("Type").font(.caption2).frame(width: 32).foregroundColor(.secondary)
            Image(systemName: "checkmark").font(.caption2).frame(width: 32).foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
    
    private var collapsedInfoSection: some View {
        HStack {
            Spacer()
            Text("Tap to expand")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: addSet) {
                Text("+ Add Set")
                    .font(.subheadline).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(exercise.isCompleted || isWorkoutCompleted) // Запрещаем добавлять сеты, если упражнение или тренировка завершены
            
            // Показываем кнопку "Finish", только если это НЕ вложенное упражнение
            if !isEmbeddedInSuperset {
                Button(action: finishExercise) {
                    Text("Finish Exercise")
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(exercise.isCompleted || isWorkoutCompleted) // Запрещаем завершать, если упражнение или тренировка завершены
                // ИСПРАВЛЕННАЯ ПОДСВЕТКА
                .spotlight(
                    step: .finishExercise,       // Убедись, что используешь правильный шаг (finishExercise)
                    manager: tutorialManager,    // Переменная @EnvironmentObject var tutorialManager
                    text: "Tap here when you are done with this exercise.",
                    alignment: .top,             // <--- СТАВИМ .top (ТЕКСТ СВЕРХУ)
                    yOffset: -20                 // <--- Чуть приподнимаем над кнопкой
                )
            }
        }
        .padding(.top, 12)
    }
    
    private var recordOverlay: some View {
        VStack {
            Image(systemName: "trophy.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            Text("New Record!")
                .font(.title).bold()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
        .transition(.opacity.combined(with: .scale))
    }
    
    // MARK: - Logic
    
    private func finishExercise() {
            // Запрещаем завершать, если упражнение или тренировка завершены
            guard !exercise.isCompleted && !isWorkoutCompleted else { return }
            
            markAllSetsCompleted()
            exercise.isCompleted = true // Помечаем упражнение как завершенное
            
            // Получаем данные о прошлой тренировке
            let lastData = viewModel.getLastPerformance(for: exercise.name, currentWorkoutId: currentWorkoutId)
            
            // Логика рекорда: Только если это силовое И (есть история ИЛИ вес > 0)
            // Но ты просил "если первый раз - не показывать".
            // Значит, проверяем: lastData != nil
            
            if exercise.type == .strength {
                let maxWeightInWorkout = exercise.setsList
                    .filter { $0.isCompleted }
                    .compactMap { $0.weight }
                    .max() ?? 0
                
                // Если история ЕСТЬ, сравниваем.
                if let _ = lastData {
                    let oldRecord = viewModel.getPersonalRecord(for: exercise.name, onlyCompleted: true)
                    if maxWeightInWorkout > oldRecord {
                        triggerRecordAnimation()
                    }
                }
                // Если истории НЕТ (первый раз), ничего не делаем.
            }
            
            // ТУТОРИАЛ
            if tutorialManager.currentStep == .finishExercise {
                tutorialManager.setStep(.explainEffort)
            }
            
            showEffortSheet = true
        }
    
    private func triggerRecordAnimation() {
        withAnimation { showPRCelebration = true }
        
        // Скрываем через 3 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showPRCelebration = false }
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func markAllSetsCompleted() {
        for i in 0..<exercise.setsList.count {
            exercise.setsList[i].isCompleted = true
        }
    }
    
    private func addSet() {
        // Запрещаем добавлять сеты, если упражнение или тренировка завершены
        guard !exercise.isCompleted && !isWorkoutCompleted else { return }
        
        let newIndex = exercise.setsList.count + 1
        let lastSet = exercise.setsList.last
        
        // Копируем данные из предыдущего сета для удобства
        let newSet = WorkoutSet(
            index: newIndex,
            weight: lastSet?.weight,
            reps: lastSet?.reps,
            distance: lastSet?.distance,
            time: lastSet?.time
        )
        
        withAnimation {
            exercise.setsList.append(newSet)
        }
    }
    
    private func removeSet(at index: Int) {
        // Запрещаем удалять сеты, если упражнение или тренировка завершены
        guard !exercise.isCompleted && !isWorkoutCompleted else { return }
        
        withAnimation {
            if index < exercise.setsList.count {
                exercise.setsList.remove(at: index)
                // Пересчитываем индексы
                for i in 0..<exercise.setsList.count {
                    exercise.setsList[i].index = i + 1
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func getIcon() -> String {
        switch exercise.type {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .duration: return "stopwatch.fill"
        }
    }
    
    private func getColor() -> Color {
        switch exercise.type {
        case .strength: return .blue
        case .cardio: return .orange
        case .duration: return .purple
        }
    }
}

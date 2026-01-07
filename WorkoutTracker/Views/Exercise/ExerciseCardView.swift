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
    @StateObject private var unitsManager = UnitsManager.shared
    
    // MARK: - Properties
    
    let currentWorkoutId: UUID
    var onDelete: () -> Void
    var onSwap: (() -> Void)? = nil
    var isEmbeddedInSuperset: Bool = false // Флаг: скрывать кнопку Finish, если это часть суперсета
    var isWorkoutCompleted: Bool = false // Флаг завершения тренировки
    var isCurrentExercise: Bool = false // Флаг: является ли это упражнение текущим (активным)
    
    // MARK: - Local State
    
    @State private var showEffortSheet = false
    @State private var showPRCelebration = false
    @Binding var isExpanded: Bool // Состояние раскрытия/сворачивания упражнения (управляется извне)
    @State private var showDeleteAlert = false
    
    // Callback при завершении упражнения (вызывается после закрытия EffortSheet)
    var onExerciseFinished: (() -> Void)? = nil
    
    // MARK: - Initializer
    
    init(
        exercise: Binding<Exercise>,
        currentWorkoutId: UUID,
        onDelete: @escaping () -> Void,
        onSwap: (() -> Void)? = nil,
        isEmbeddedInSuperset: Bool = false,
        isWorkoutCompleted: Bool = false,
        isExpanded: Binding<Bool>,
        onExerciseFinished: (() -> Void)? = nil,
        isCurrentExercise: Bool = false
    ) {
        self._exercise = exercise
        self.currentWorkoutId = currentWorkoutId
        self.onDelete = onDelete
        self.onSwap = onSwap
        self.isEmbeddedInSuperset = isEmbeddedInSuperset
        self.isWorkoutCompleted = isWorkoutCompleted
        self._isExpanded = isExpanded
        self.onExerciseFinished = onExerciseFinished
        self.isCurrentExercise = isCurrentExercise
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
                                    Label(LocalizedStringKey("Delete"), systemImage: "trash")
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
            .background(
                isCurrentExercise && !exercise.isCompleted
                    ? Color.blue.opacity(0.08)
                    : Color(UIColor.secondarySystemBackground)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isCurrentExercise && !exercise.isCompleted
                            ? Color.blue.opacity(0.5)
                            : Color.clear,
                        lineWidth: isCurrentExercise && !exercise.isCompleted ? 2 : 0
                    )
            )
            .shadow(
                color: isCurrentExercise && !exercise.isCompleted
                    ? Color.blue.opacity(0.2)
                    : Color.clear,
                radius: isCurrentExercise && !exercise.isCompleted ? 8 : 0,
                x: 0,
                y: 2
            )
            
            // Оверлей рекорда (PR)
            if showPRCelebration {
                recordOverlay
            }
        }
        // Модификаторы
        .sheet(isPresented: $showEffortSheet, onDismiss: {
            // После закрытия EffortSheet вызываем callback для сворачивания и перехода к следующему упражнению
            if exercise.isCompleted {
                onExerciseFinished?()
            }
        }) {
            EffortInputView(effort: $exercise.effort)
        }
        .alert(LocalizedStringKey("Delete Exercise?"), isPresented: $showDeleteAlert) {
            Button(LocalizedStringKey("Delete"), role: .destructive) {
                onDelete()
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Are you sure you want to delete '\(exercise.name)'? This action cannot be undone."))
        }
        .blur(radius: showPRCelebration ? 5 : 0)
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                Text(LocalizedStringKey("\(exercise.setsList.count) sets"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Menu {
                    // Опция замены упражнения
                    if let onSwap = onSwap {
                        Button(action: onSwap) {
                            Label(LocalizedStringKey("Swap Exercise"), systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label(LocalizedStringKey("Remove Exercise"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .padding(10)
                }
                .highPriorityGesture(TapGesture().onEnded { })
            }
            
            // Таргетные мускулы
            let targetMuscles = MuscleDisplayHelper.getTargetMuscleNames(for: exercise.name, muscleGroup: exercise.muscleGroup)
            if !targetMuscles.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(targetMuscles.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 28)
            }
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
            Text(LocalizedStringKey("Set"))
                .font(.caption2)
                .frame(width: 25)
                .foregroundColor(.secondary)
            
            switch exercise.type {
            case .strength:
                Text(unitsManager.weightUnitString()).font(.caption2).frame(width: 100).foregroundColor(.secondary)
                Text(LocalizedStringKey("Reps")).font(.caption2).frame(width: 100).foregroundColor(.secondary)
            case .cardio:
                Text(LocalizedStringKey("km")).font(.caption2).frame(width: 100).foregroundColor(.secondary)
                Spacer()
                Text(LocalizedStringKey("Time")).font(.caption2).frame(width: 100).foregroundColor(.secondary)
            case .duration:
                Text(LocalizedStringKey("Time")).font(.caption2).frame(width: 100).foregroundColor(.secondary)
            }
            
            Text(LocalizedStringKey("Type")).font(.caption2).frame(width: 32).foregroundColor(.secondary)
            Image(systemName: "checkmark").font(.caption2).frame(width: 32).foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
    
    private var collapsedInfoSection: some View {
        HStack {
            Spacer()
            Text(LocalizedStringKey("Tap to expand"))
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
                Text(LocalizedStringKey("+ Add Set"))
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
                    Text(LocalizedStringKey("Finish Exercise"))
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(exercise.isCompleted || isWorkoutCompleted)
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
            Text(LocalizedStringKey("New Record!"))
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

//
//  AddWorkoutView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI
import ActivityKit

struct AddWorkoutView: View {
    
    // MARK: - Environment & Bindings
    @EnvironmentObject var tutorialManager: TutorialManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WorkoutViewModel
    
    @Binding var workouts: [Workout]
    var onWorkoutCreated: (() -> Void)?
    
    @State private var title = ""
    @State private var selectedPreset: WorkoutPreset?
    
    var body: some View {
        NavigationStack {
            // 1. ZStack для наложения подсветки на тулбар
            ZStack(alignment: .topTrailing) {
                
                Form {
                    nameSection
                    
                    templateSelectionSection
                }
                
                // 2. ФАНТОМНАЯ КНОПКА ПОДСВЕТКИ (Для кнопки Start Now)
                if !title.isEmpty {
                    Color.clear
                        .frame(width: 100, height: 45) // 1. Сначала задаем размер ТОЛЬКО под кнопку
                        .spotlight(                   // 2. Сразу вешаем подсветку на этот маленький размер
                            step: .tapStartNow,
                            manager: tutorialManager,
                            text: "Great! Now tap here",
                            alignment: .bottom, // Пузырь снизу-справа
                            xOffset: -10,
                            yOffset: -20
                        )
                        // 3. И только ТЕПЕРЬ двигаем эту подсвеченную коробочку в нужный угол
                        .padding(.top, -105)           // Поднимаем вверх на уровень Toolbar
                        .padding(.trailing, 25)       // Отступ от правого края
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) // Прижимаем к углу
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Start Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Now") {
                        startWorkout()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if title.isEmpty { setFormattedDateName() }
            }
        }
    }
    
    // MARK: - Components
    
    private var nameSection: some View {
        Section(header: Text("Workout Name")) {
            TextField("E.g. Evening Pump", text: $title)
        }
    }
    
    private var templateSelectionSection: some View {
        Section(
            header: Text("Choose Template"),
            footer: Text("You can change your prepared workouts in the settings..")
        ) {
            // Кнопка "Пустая тренировка"
            Button {
                selectPreset(nil)
            } label: {
                templateRow(
                    iconName: "plus.square.dashed",
                    title: "Empty Workout",
                    subtitle: "Start from scratch",
                    isSystemIcon: true,
                    isSelected: selectedPreset == nil
                )
            }
            .buttonStyle(.plain)
            .spotlight(
                step: .createEmpty,
                manager: tutorialManager,
                text: "Start from scratch without a template",
                alignment: .top,
                yOffset: -10
            )
            
            // Список шаблонов
            ForEach(viewModel.presets) { preset in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        selectPreset(preset)
                    } label: {
                        templateRow(
                            iconName: preset.icon,
                            title: preset.name,
                            subtitle: "\(preset.exercises.count) exercises",
                            isSystemIcon: false,
                            isSelected: selectedPreset?.id == preset.id
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Показываем упражнения непосредственно под выбранным шаблоном
                    if selectedPreset?.id == preset.id {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(preset.exercises) { ex in
                                exercisePreviewRow(exercise: ex)
                            }
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                }
            }
        }
    }
    
    private func exercisePreviewRow(exercise: Exercise) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 6, height: 6)
            
            Text(exercise.name)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(formatExerciseDetails(exercise))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
    
    private func formatExerciseDetails(_ exercise: Exercise) -> String {
        switch exercise.type {
        case .strength:
            if exercise.weight > 0 {
                return "\(exercise.sets)/\(exercise.reps) \(Int(exercise.weight))kg"
            } else {
                return "\(exercise.sets)/\(exercise.reps)"
            }
        case .cardio:
            if let distance = exercise.distance, distance > 0 {
                return "\(exercise.sets) x \(String(format: "%.1f", distance))km"
            } else {
                return "\(exercise.sets) sets"
            }
        case .duration:
            if let timeSeconds = exercise.timeSeconds, timeSeconds > 0 {
                let minutes = timeSeconds / 60
                return "\(exercise.sets) x \(minutes)min"
            } else {
                return "\(exercise.sets) sets"
            }
        }
    }
    
    private func templateRow(iconName: String, title: String, subtitle: String, isSystemIcon: Bool, isSelected: Bool) -> some View {
            HStack {
                Group {
                    if isSystemIcon {
                        // Системная иконка (SF Symbol) для "Empty Workout"
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundColor(.gray)
                    } else {
                        // Иконка из Assets (для шаблонов)
                        // Проверяем, существует ли картинка с таким именем
                        if UIImage(named: iconName) != nil {
                            Image(iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                                .shadow(radius: 2)
                        } else {
                            // ЗАПАСНОЙ ВАРИАНТ (Если иконки нет или старые данные)
                            Image(systemName: "dumbbell.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .padding(13) // Отступы, чтобы фон был 50x50
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                VStack(alignment: .leading) {
                    Text(title)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    
    // MARK: - Logic
    
    private func selectPreset(_ preset: WorkoutPreset?) {
        withAnimation {
            selectedPreset = preset
            if let p = preset {
                title = p.name
            } else {
                setFormattedDateName()
            }
            
            // ЛОГИКА ТУТОРИАЛА:
            // Если мы были на шаге выбора шаблона -> переходим к шагу "Нажми Старт"
            if tutorialManager.currentStep == .createEmpty {
                tutorialManager.setStep(.tapStartNow)
            }
        }
    }
    
    private func setFormattedDateName() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE Workout"
        title = formatter.string(from: Date())
    }
    
    private func startWorkout() {
        var exercisesToAdd: [Exercise] = []
        
        if let preset = selectedPreset {
            exercisesToAdd = preset.exercises.map { ex in
                return Exercise(
                    name: ex.name,
                    muscleGroup: ex.muscleGroup,
                    type: ex.type,
                    sets: ex.sets,
                    reps: ex.reps,
                    weight: ex.weight,
                    distance: ex.distance,
                    timeSeconds: ex.timeSeconds,
                    effort: ex.effort
                )
            }
        }
        
        let newWorkout = Workout(
            title: title.isEmpty ? "New Workout" : title,
            date: Date(),
            exercises: exercisesToAdd
        )
        
        workouts.insert(newWorkout, at: 0)
        startLiveActivity()
        dismiss()
        
        // ЛОГИКА ТУТОРИАЛА:
        // После нажатия Старт -> переходим к шагу "Добавь упражнение"
        if tutorialManager.currentStep == .tapStartNow {
            // Делаем небольшую задержку, чтобы экран успел смениться
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                tutorialManager.setStep(.addExercise)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onWorkoutCreated?()
        }
    }
    
    private func startLiveActivity() {
        let attributes = WorkoutActivityAttributes(workoutTitle: title)
        let state = WorkoutActivityAttributes.ContentState(startTime: Date())
        do {
            _ = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
        }
    }
}

//
//  AddWorkoutView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI
import SwiftData
import ActivityKit

struct AddWorkoutView: View {
    
    // MARK: - Environment & Bindings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var tutorialManager: TutorialManager
    @EnvironmentObject private var viewModel: WorkoutViewModel
@EnvironmentObject var unitsManager: UnitsManager
    
    // Шаблоны из базы
    @Query(sort: \WorkoutPreset.name) private var presets: [WorkoutPreset]
    
    var onWorkoutCreated: (() -> Void)?
    
    @State private var title = ""
    @State private var selectedPreset: WorkoutPreset?
    
    // Состояние для алерта активной тренировки
    @State private var showActiveWorkoutAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                
                Form {
                    nameSection
                    
                    templateSelectionSection
                }
                
                if !title.isEmpty {
                    Color.clear
                        .frame(width: 100, height: 45)
                        .spotlight(
                            step: .tapStartNow,
                            manager: tutorialManager,
                            text: "Great! Now tap here",
                            alignment: .bottom, // Пузырь снизу-справа
                            xOffset: -10,
                            yOffset: -20
                        )
                        .padding(.top, -105)
                        .padding(.trailing, 25)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(LocalizedStringKey("Start Workout"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Start Now")) {
                        checkAndStartWorkout()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if title.isEmpty { setFormattedDateName() }
            }
            .alert(LocalizedStringKey("Active Workout Exists"), isPresented: $showActiveWorkoutAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { dismiss() }
            } message: {
                Text(LocalizedStringKey("You already have an active workout in progress. Please finish or delete it before starting a new one."))
            }
        }
    }
    
    // MARK: - Components
    
    private var nameSection: some View {
        Section(header: Text(LocalizedStringKey("Workout Name"))) {
            TextField(LocalizedStringKey("E.g. Evening Pump"), text: $title)
        }
    }
    
    private var templateSelectionSection: some View {
        Section(
            header: Text(LocalizedStringKey("Choose Template")),
            footer: Text(LocalizedStringKey("You can change your prepared workouts in the settings.."))
        ) {
            // Кнопка "Пустая тренировка"
            Button {
                selectPreset(nil)
            } label: {
                templateRow(
                    iconName: "plus.square.dashed",
                    title: LocalizedStringKey("Empty Workout"),
                    subtitle: LocalizedStringKey("Start from scratch"),
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
            ForEach(presets) { preset in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        selectPreset(preset)
                    } label: {
                        templateRow(
                            iconName: preset.icon,
                            title: LocalizedStringKey(preset.name),
                            subtitle: LocalizedStringKey("\(preset.exercises.count) exercises"),
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
            if exercise.firstSetWeight > 0 {
                let convertedWeight = unitsManager.convertFromKilograms(exercise.firstSetWeight)
                return "\(exercise.setsCount)/\(exercise.firstSetReps) \(Int(convertedWeight))\(unitsManager.weightUnitString())"
            } else {
                return "\(exercise.setsCount)/\(exercise.firstSetReps)"
            }
        case .cardio:
            if let distance = exercise.firstSetDistance, distance > 0 {
                return "\(exercise.setsCount) x \(LocalizationHelper.shared.formatDecimal(distance))km"
            } else {
                return "\(exercise.setsCount) sets"
            }
        case .duration:
            if let timeSeconds = exercise.firstSetTimeSeconds, timeSeconds > 0 {
                let minutes = timeSeconds / 60
                return "\(exercise.setsCount) x \(minutes)min"
            } else {
                return "\(exercise.setsCount) sets"
            }
        }
    }
    
    private func templateRow(iconName: String, title: LocalizedStringKey, subtitle: LocalizedStringKey, isSystemIcon: Bool, isSelected: Bool) -> some View {
            HStack {
                Group {
                    if isSystemIcon {
                        // Системная иконка (SF Symbol) для "Empty Workout"
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundColor(.gray)
                    } else {
                        // Иконка из Assets (для шаблонов)
                        if UIImage(named: iconName) != nil {
                            Image(iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                                .shadow(radius: 2)
                        } else {
                            Image(systemName: "dumbbell.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .padding(13)
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
            if tutorialManager.currentStep == .createEmpty {
                tutorialManager.setStep(.tapStartNow)
            }
        }
    }
    
    private func setFormattedDateName() {
        title = LocalizationHelper.shared.formatWorkoutDateName()
    }
    
    // 1. Проверяем наличие активных тренировок
    private func checkAndStartWorkout() {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endTime == nil }
        )
        
        if let activeWorkouts = try? context.fetch(descriptor), !activeWorkouts.isEmpty {
            // Найдена активная тренировка - показываем алерт
            showActiveWorkoutAlert = true
        } else {
            // Если всё чисто, запускаем новую
            startWorkout()
        }
    }
    
    private func startWorkout() {
        var exercisesToAdd: [Exercise] = []
        if let preset = selectedPreset {
            exercisesToAdd = preset.exercises.map { $0.duplicate() }
        }
        
        let newWorkout = Workout(
            title: title.isEmpty ? LocalizationHelper.shared.formatWorkoutDateName() : title,
            date: Date(),
            exercises: exercisesToAdd
        )
        
        context.insert(newWorkout)
        try? context.save()
        
        // PASS THE ACTUAL WORKOUT TITLE
        startLiveActivity(with: newWorkout.title)
        
        dismiss()
        
        if tutorialManager.currentStep == .tapStartNow {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                tutorialManager.setStep(.addExercise)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onWorkoutCreated?()
        }
    }

    private func startLiveActivity(with title: String) {
        let attributes = WorkoutActivityAttributes(workoutTitle: title)
        let state = WorkoutActivityAttributes.ContentState(startTime: Date())
        _ = try? Activity<WorkoutActivityAttributes>.request(attributes: attributes, content: .init(state: state, staleDate: nil), pushType: nil)
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
            // Error starting Live Activity
        }
    }
}

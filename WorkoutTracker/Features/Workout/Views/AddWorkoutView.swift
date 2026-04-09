// ============================================================
// FILE: WorkoutTracker/Views/Workout/AddWorkoutView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(DIContainer.self) private var di
    @Environment(UnitsManager.self) var unitsManager
    
    @Query(sort: \WorkoutPreset.name) private var presets: [WorkoutPreset]
    
    // ✅ Инициализируем ViewModel чисто и просто
    @State private var viewModel = AddWorkoutViewModel()
    
    var onWorkoutCreated: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Form {
                    nameSection
                    templateSelectionSection
                }
                
                if !viewModel.title.isEmpty {
                    Color.clear
                        .frame(width: 100, height: 45)
                        .spotlight(
                            step: .tapStartNow,
                            manager: tutorialManager,
                            text: "Great! Now tap here",
                            alignment: .bottom,
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
                        Task {
                            // Передаем сервисы из Environment прямо в метод
                            await viewModel.checkAndStartWorkout(
                                workoutService: di.workoutService,
                                liveActivityManager: di.liveActivityManager
                            ) {
                                dismiss()
                                if tutorialManager.currentStep == .tapStartNow {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { tutorialManager.setStep(.addExercise) }
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onWorkoutCreated?() }
                            }
                        }
                    }
                    .disabled(viewModel.title.isEmpty)
                }
            }
            .alert(LocalizedStringKey("Active Workout Exists"), isPresented: $viewModel.showActiveWorkoutAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { dismiss() }
            } message: {
                Text(LocalizedStringKey("You already have an active workout in progress. Please finish or delete it before starting a new one."))
            }
        }
    }
    
    private var nameSection: some View {
        Section(header: Text(LocalizedStringKey("Workout Name"))) {
            TextField(LocalizedStringKey("E.g. Evening Pump"), text: $viewModel.title)
        }
    }
    
    private var templateSelectionSection: some View {
        Section(
            header: Text(LocalizedStringKey("Choose Template")),
            footer: Text(LocalizedStringKey("You can change your prepared workouts in the settings.."))
        ) {
            Button {
                withAnimation {
                    viewModel.selectPreset(nil)
                    if tutorialManager.currentStep == .createEmpty { tutorialManager.setStep(.tapStartNow) }
                }
            } label: {
                templateRow(
                    iconName: "plus.square.dashed",
                    title: LocalizedStringKey("Empty Workout"),
                    subtitle: LocalizedStringKey("Start from scratch"),
                    isSystemIcon: true,
                    isSelected: viewModel.selectedPreset == nil
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
            
            ForEach(presets) { preset in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation {
                            viewModel.selectPreset(preset)
                            if tutorialManager.currentStep == .createEmpty { tutorialManager.setStep(.tapStartNow) }
                        }
                    } label: {
                        templateRow(
                            iconName: preset.icon,
                            title: LocalizedStringKey(preset.name),
                            subtitle: LocalizedStringKey("\(preset.exercises.count) exercises"),
                            isSystemIcon: false,
                            isSelected: viewModel.selectedPreset?.id == preset.id
                        )
                    }
                    .buttonStyle(.plain)
                    
                    if viewModel.selectedPreset?.id == preset.id {
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
            Circle().fill(Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
            Text(LocalizationHelper.shared.translateName(exercise.name)).foregroundColor(.secondary)
            Spacer()
            Text(exercise.formattedDetails(unitsManager: unitsManager))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
    
    private func templateRow(iconName: String, title: LocalizedStringKey, subtitle: LocalizedStringKey, isSystemIcon: Bool, isSelected: Bool) -> some View {
        HStack {
            Group {
                if isSystemIcon {
                    Image(systemName: iconName).font(.title2).foregroundColor(.gray)
                } else {
                    if UIImage(named: iconName) != nil {
                        Image(iconName).resizable().aspectRatio(contentMode: .fit).frame(width: 50, height: 50).cornerRadius(8).shadow(radius: 2)
                    } else {
                        Image(systemName: "dumbbell.fill").resizable().aspectRatio(contentMode: .fit).frame(width: 24, height: 24).padding(13).background(Color.gray.opacity(0.1)).cornerRadius(8).foregroundColor(.blue)
                    }
                }
            }
            
            VStack(alignment: .leading) {
                Text(title).foregroundColor(.primary)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if isSelected { Image(systemName: "checkmark.circle.fill").foregroundColor(.blue) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

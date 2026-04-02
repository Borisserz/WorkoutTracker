
internal import SwiftUI
import SwiftData

// MARK: - PresetFormViewModel (New DTO for form state)
@Observable
final class PresetFormViewModel {
    var name: String = ""
    var selectedIcon: String = "img_default"
    var exercises: [Exercise] = [] // This will hold copies of exercises
    
    // For validation
    var nameIsValid: Bool = false
    var exercisesAreValid: Bool = false
    
    func load(from preset: WorkoutPreset?) {
        if let p = preset {
            self.name = p.name
            self.selectedIcon = p.icon
            // IMPORTANT: Create copies of exercises to avoid direct mutation of @Model
            self.exercises = p.exercises.map { $0.duplicate() }
        } else {
            self.name = ""
            self.selectedIcon = "img_default"
            self.exercises = []
        }
        validate()
    }
    
    func validate() {
        nameIsValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        exercisesAreValid = !exercises.isEmpty
    }
}


// MARK: - Main Editor View

struct PresetEditorView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutService.self) private var workoutService
    @Environment(UnitsManager.self) var unitsManager
    
    var preset: WorkoutPreset? // Existing preset (if editing)
    
    // Local ViewModel for form state
    @State private var vm = PresetFormViewModel()
    
    // Управление модальными окнами
    @State private var showExerciseSelector = false
    @State private var exerciseToEdit: Exercise?
    @State private var showDeleteAlert = false
    @State private var showDeleteExerciseAlert = false
    @State private var exercisesToDelete: IndexSet?
    
    // Доступные иконки
    private let availableIcons = [
        "img_default", "img_chest", "img_chest2", "img_back", "img_back2",
        "img_legs", "img_legs2", "img_arms", "battle-rope", "dumbbell",
        "exercise-2", "gym-4"
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. Имя и Иконка
                headerSection
                
                // 2. Список упражнений
                exerciseListSection
                
                // 3. Удаление (только для существующих)
                if preset != nil {
                    deleteButtonSection
                }
            }
            .navigationTitle(preset == nil ? String(localized: "New Template") : String(localized: "Edit Template"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        Task { await savePreset() }
                    }
                    .disabled(!vm.nameIsValid || !vm.exercisesAreValid)
                }
            }
            // Алерт удаления шаблона
            .alert(String(localized: "Delete Template?"), isPresented: $showDeleteAlert) {
                Button(String(localized: "Delete"), role: .destructive) {
                    if let p = preset {
                        Task { await workoutService.deletePreset(p) }
                        dismiss()
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) { }
            } message: {
                Text(String(localized: "Are you sure you want to delete '\(vm.name)'? This action cannot be undone."))
            }
            // Алерт удаления упражнения
            .alert(String(localized: "Delete Exercise?"), isPresented: $showDeleteExerciseAlert) {
                Button(String(localized: "Delete"), role: .destructive) {
                    if let indexSet = exercisesToDelete {
                        vm.exercises.remove(atOffsets: indexSet)
                        vm.validate() // Revalidate after removal
                        exercisesToDelete = nil
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    exercisesToDelete = nil
                }
            } message: {
                if let indexSet = exercisesToDelete {
                    let count = indexSet.count
                    if count == 1, let firstIndex = indexSet.first, firstIndex < vm.exercises.count {
                        let exName = vm.exercises[firstIndex].name
                        Text(String(localized: "Are you sure you want to delete '\(exName)'? This action cannot be undone."))
                    } else {
                        Text(String(localized: "Are you sure you want to delete \(count) exercises? This action cannot be undone."))
                    }
                } else {
                    Text(String(localized: "Are you sure you want to delete this exercise? This action cannot be undone."))
                }
            }
            // Инициализация ViewModel
            .onAppear {
                vm.load(from: preset)
            }
            // Добавление упражнения
            .sheet(isPresented: $showExerciseSelector) {
                ExerciseSelectionView { newExercise in
                    vm.exercises.append(newExercise)
                    vm.validate() // Revalidate after addition
                }
            }
            // Редактирование упражнения
            .sheet(item: $exerciseToEdit) { ex in
                PresetExerciseEditor(exercise: ex.duplicate()) { updatedEx in // Pass a copy
                    if let index = vm.exercises.firstIndex(where: { $0.id == ex.id }) {
                        vm.exercises[index] = updatedEx
                    }
                    exerciseToEdit = nil
                    vm.validate() // Revalidate after edit
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        Section(header: Text(String(localized: "Template Info"))) {
            TextField(String(localized: "Template Name"), text: $vm.name)
                .onChange(of: vm.name) { _, _ in vm.validate() }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(availableIcons, id: \.self) { iconName in
                        Image(iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(vm.selectedIcon == iconName ? Color.blue : Color.clear, lineWidth: 3)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation { vm.selectedIcon = iconName }
                            }
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    private var exerciseListSection: some View {
        Section(header: Text(String(localized: "Exercises"))) {
            if vm.exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text(String(localized: "No exercises yet"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(String(localized: "Tap the button below to add your first exercise to this template"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
            
            ForEach(vm.exercises) { exercise in
                HStack {
                    VStack(alignment: .leading) {
                        Text(exercise.name).font(.headline)
                        
                        Group {
                            switch exercise.type {
                            case .strength:
                                let convertedWeight = unitsManager.convertFromKilograms(exercise.firstSetWeight)
                                Text("\(exercise.setsCount) x \(exercise.firstSetReps) • \(Int(convertedWeight))\(unitsManager.weightUnitString())")
                            case .cardio:
                                let dist = exercise.firstSetDistance ?? 0
                                let convertedDist = unitsManager.convertFromMeters(dist)
                                let time = exercise.firstSetTimeSeconds ?? 0
                                Text("\(LocalizationHelper.shared.formatTwoDecimals(convertedDist)) \(unitsManager.distanceUnitString()) • \(formatTime(time))")
                            case .duration:
                                let time = exercise.firstSetTimeSeconds ?? 0
                                Text("\(exercise.setsCount) sets • \(formatTime(time))")
                            }
                        }
                        .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button {
                        exerciseToEdit = exercise
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .onDelete { indexSet in
                exercisesToDelete = indexSet
                showDeleteExerciseAlert = true
            }
            
            Button {
                showExerciseSelector = true
            } label: {
                Label(String(localized: "Add Exercise"), systemImage: "plus")
            }
        }
    }
    
    private var deleteButtonSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text(String(localized: "Delete Template"))
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    private func savePreset() async {
        await workoutService.savePreset(preset: preset, name: vm.name, icon: vm.selectedIcon, exercises: vm.exercises)
        dismiss()
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Inner Exercise Editor

// New ViewModel for Preset Exercise Editor
@Observable
final class PresetExerciseFormViewModel {
    var setsCount: Int = 1
    var repsCount: Int = 0
    var weightValue: Double = 0
    var distanceValue: Double? = nil
    var minutes: Int = 0
    var seconds: Int = 0
    
    var validationErrorMessage: String? = nil
    
    func load(from exercise: Exercise) {
        setsCount = exercise.setsList.count > 0 ? exercise.setsList.count : 1
        repsCount = exercise.firstSetReps
        weightValue = exercise.firstSetWeight
        distanceValue = exercise.firstSetDistance
        
        let total = exercise.firstSetTimeSeconds ?? 0
        minutes = total / 60
        seconds = total % 60
    }
    
    func validate(for type: ExerciseType, unitsManager: UnitsManager) -> Bool {
        var errorMessages: [String] = []
        
        if type == .strength {
            let actualWeight = weightValue
            let weightValidation = InputValidator.validateWeight(actualWeight)
            if !weightValidation.isValid {
                errorMessages.append(weightValidation.errorMessage ?? "Invalid weight")
                weightValue = weightValidation.clampedValue
            }
            
            let repsValidation = InputValidator.validateReps(repsCount)
            if !repsValidation.isValid {
                errorMessages.append(repsValidation.errorMessage ?? "Invalid reps")
                repsCount = repsValidation.clampedValue
            }
        }
        
        if type == .cardio {
            let actualDistance = distanceValue ?? 0.0
            let distValidation = InputValidator.validateDistance(actualDistance)
            if !distValidation.isValid {
                errorMessages.append(distValidation.errorMessage ?? "Invalid distance")
                distanceValue = distValidation.clampedValue
            }
        }
        
        let totalSeconds = (minutes * 60) + seconds
        if totalSeconds > 0 {
            let timeValidation = InputValidator.validateTime(totalSeconds)
            if !timeValidation.isValid {
                errorMessages.append(timeValidation.errorMessage ?? "Invalid time")
                minutes = timeValidation.clampedValue / 60
                seconds = timeValidation.clampedValue % 60
            }
        }
        
        if errorMessages.isEmpty {
            validationErrorMessage = nil
            return true
        } else {
            validationErrorMessage = errorMessages.joined(separator: "\n")
            return false
        }
    }
}

struct PresetExerciseEditor: View {
    // ✅ РЕФАКТОРИНГ: Удалили зависимость от WorkoutViewModel
    @Environment(\.modelContext) private var context
    
    var exercise: Exercise // Now passed as a copy
    var onSave: (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(UnitsManager.self) var unitsManager
    
    @State private var vm = PresetExerciseFormViewModel() // Local ViewModel
    @State private var showValidationAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(exercise.name)) {
                    switch exercise.type {
                    case .strength: strengthConfig
                    case .cardio: cardioConfig
                    case .duration: durationConfig
                    }
                }
                
                Button(String(localized: "Save Changes")) {
                    save()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle(String(localized: "Configure Preset"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .onAppear {
                vm.load(from: exercise)
            }
            .alert(String(localized: "Invalid Input"), isPresented: $showValidationAlert) {
                Button(String(localized: "OK"), role: .cancel) { }
            } message: {
                Text(vm.validationErrorMessage ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Config Subviews
    
    @ViewBuilder
    private var strengthConfig: some View {
        Stepper(String(localized: "Sets: \(vm.setsCount)"), value: $vm.setsCount, in: 1...20)
        Stepper(String(localized: "Reps: \(vm.repsCount)"), value: $vm.repsCount, in: 0...100)
        HStack {
            Text(String(localized: "Weight (\(unitsManager.weightUnitString())):"))
            TextField("0", value: Binding(get: { unitsManager.convertFromKilograms(vm.weightValue) }, set: { vm.weightValue = unitsManager.convertToKilograms($0) }), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
    
    @ViewBuilder
    private var cardioConfig: some View {
        HStack {
            Text(String(localized: "Distance (\(unitsManager.distanceUnitString())):"))
            TextField("0", value: Binding(get: {
                if let d = vm.distanceValue { return unitsManager.convertFromMeters(d) }
                return 0
            }, set: { newValue in
                vm.distanceValue = unitsManager.convertToMeters(newValue)
            }), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }
        timePickerRow(label: "Duration")
    }
    
    @ViewBuilder
    private var durationConfig: some View {
        Stepper(String(localized: "Sets: \(vm.setsCount)"), value: $vm.setsCount, in: 1...10)
        timePickerRow(label: "Time per set")
    }
    
    private func timePickerRow(label: String) -> some View {
        HStack {
            Text(LocalizedStringKey(label))
            Spacer()
            TextField("0", value: $vm.minutes, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
            Text(String(localized: "min"))
            TextField("0", value: $vm.seconds, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
                .onChange(of: vm.seconds) { oldValue, newValue in
                    let clampedSeconds = max(0, min(newValue, 59))
                    if clampedSeconds != newValue {
                        vm.seconds = clampedSeconds
                    }
                }
            Text(String(localized: "sec"))
        }
    }
    
    // MARK: - Logic
    
    private func save() {
        guard vm.validate(for: exercise.type, unitsManager: unitsManager) else {
            showValidationAlert = true
            return
        }
        
        // Update the copy of the exercise
        let finalSetsCount = exercise.type == .cardio ? 1 : max(1, vm.setsCount)
        let totalSeconds = (vm.minutes * 60) + vm.seconds
        
        var newSets: [WorkoutSet] = []
        for i in 1...finalSetsCount {
            newSets.append(WorkoutSet(
                index: i,
                weight: exercise.type == .strength ? vm.weightValue : nil,
                reps: exercise.type == .strength ? vm.repsCount : nil,
                distance: exercise.type == .cardio ? vm.distanceValue : nil,
                time: totalSeconds > 0 ? totalSeconds : nil,
                isCompleted: false,
                type: .normal
            ))
        }
        
        // Replace sets in the local copy of the exercise
        exercise.replaceAllSets(with: newSets)
        
        onSave(exercise) // Pass the updated copy back
        dismiss()
    }
}

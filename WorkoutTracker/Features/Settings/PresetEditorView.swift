// ============================================================
// FILE: WorkoutTracker/Views/Settings/PresetEditorView.swift
// ============================================================

internal import SwiftUI
internal import UniformTypeIdentifiers
import SwiftData

// MARK: - PresetFormViewModel (DTO Form State)
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
            self.exercises = p.exercises.map { Exercise(from: $0.toDTO()) }
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
    @Environment(PresetService.self) private var presetService
    @Environment(UnitsManager.self) var unitsManager
    
    var preset: WorkoutPreset? // Existing preset (if editing)
    
    @State private var vm = PresetFormViewModel()
    @State private var draggedExercise: Exercise? // Drag & Drop State
    
    @State private var showExerciseSelector = false
    @State private var exerciseToEdit: Exercise?
    @State private var showDeleteAlert = false
    @State private var showDeleteExerciseAlert = false
    @State private var exercisesToDelete: IndexSet?
    
    private let availableIcons = [
        "img_default", "img_chest", "img_chest2", "img_back", "img_back2",
        "img_legs", "img_legs2", "img_arms", "battle-rope", "dumbbell1",
        "exercise-2", "gym-4"
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        iconsSection
                        exerciseListSection
                        
                        if preset != nil {
                            deleteButtonSection
                        }
                        
                        Spacer(minLength: 100) // Space for floating save button
                    }
                }
                
                // Floating Save Button
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    Task { await savePreset() }
                } label: {
                    Text(preset == nil ? LocalizedStringKey("Save Template") : LocalizedStringKey("Save Changes"))
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            (!vm.nameIsValid || !vm.exercisesAreValid)
                            ? AnyShapeStyle(Color.gray.opacity(0.8))
                            : AnyShapeStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .cornerRadius(20)
                        .shadow(color: (!vm.nameIsValid || !vm.exercisesAreValid) ? .clear : .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .disabled(!vm.nameIsValid || !vm.exercisesAreValid)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .background(
                    LinearGradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemGroupedBackground).opacity(0)], startPoint: .bottom, endPoint: .top)
                        .ignoresSafeArea()
                )
            }
            .navigationTitle(preset == nil ? LocalizedStringKey("New Template") : LocalizedStringKey("Edit Template"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .alert(LocalizedStringKey("Delete Template?"), isPresented: $showDeleteAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    if let p = preset {
                        Task { await presetService.deletePreset(p) }
                        dismiss()
                    }
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("Are you sure you want to delete '\(vm.name)'? This action cannot be undone."))
            }
            .alert(LocalizedStringKey("Delete Exercise?"), isPresented: $showDeleteExerciseAlert) {
                Button(LocalizedStringKey("Delete"), role: .destructive) {
                    if let indexSet = exercisesToDelete {
                        vm.exercises.remove(atOffsets: indexSet)
                        vm.validate()
                        exercisesToDelete = nil
                    }
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) {
                    exercisesToDelete = nil
                }
            } message: {
                if let indexSet = exercisesToDelete {
                    let count = indexSet.count
                    if count == 1, let firstIndex = indexSet.first, firstIndex < vm.exercises.count {
                        let exName = vm.exercises[firstIndex].name
                        Text(LocalizedStringKey("Are you sure you want to delete '\(exName)'? This action cannot be undone."))
                    } else {
                        Text(LocalizedStringKey("Are you sure you want to delete \(count) exercises? This action cannot be undone."))
                    }
                } else {
                    Text(LocalizedStringKey("Are you sure you want to delete this exercise? This action cannot be undone."))
                }
            }
            .onAppear {
                vm.load(from: preset)
            }
            .sheet(isPresented: $showExerciseSelector) {
                ExerciseSelectionView { newExercise in
                    vm.exercises.append(newExercise)
                    vm.validate()
                }
            }
            .sheet(item: $exerciseToEdit) { ex in
                PresetExerciseEditor(exercise: Exercise(from: ex.toDTO())) { updatedEx in
                    if let index = vm.exercises.firstIndex(where: { $0.id == ex.id }) {
                        vm.exercises[index] = updatedEx
                    }
                    exerciseToEdit = nil
                    vm.validate()
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        TextField(LocalizedStringKey("Workout Name..."), text: $vm.name)
            .font(.system(size: 32, weight: .heavy, design: .rounded))
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .onChange(of: vm.name) { _, _ in vm.validate() }
    }
    
    private var iconsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Spacer().frame(width: 8)
                
                ForEach(availableIcons, id: \.self) { iconName in
                    let isSelected = vm.selectedIcon == iconName
                    
                    ZStack {
                        Circle()
                            .fill(isSelected
                                  ? LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                  : LinearGradient(colors: [Color(UIColor.secondarySystemBackground), Color(UIColor.secondarySystemBackground)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 60, height: 60)
                            .shadow(color: isSelected ? .cyan.opacity(0.4) : .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        
                        Image(iconName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(isSelected ? .white : .gray.opacity(0.6))
                    }
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .padding(.vertical, 10)
                    .contentShape(Circle())
                    .onTapGesture {
                        let gen = UISelectionFeedbackGenerator()
                        gen.selectionChanged()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            vm.selectedIcon = iconName
                        }
                    }
                }
                Spacer().frame(width: 8)
            }
        }
    }
    
    private var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Exercises"))
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            
            if vm.exercises.isEmpty {
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    showExerciseSelector = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text(LocalizedStringKey("Add First Exercise"))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                    )
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 12) {
                    ForEach(vm.exercises) { exercise in
                        exerciseCard(for: exercise)
                            .onDrag {
                                self.draggedExercise = exercise
                                return NSItemProvider(object: exercise.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: ExerciseDropDelegate(item: exercise, items: $vm.exercises, draggedItem: $draggedExercise))
                    }
                }
                .padding(.horizontal, 20)
                
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    showExerciseSelector = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text(LocalizedStringKey("Add Exercise"))
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
    }
    
    @ViewBuilder
    private func exerciseCard(for exercise: Exercise) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "line.3.horizontal")
                .font(.title3)
                .foregroundColor(.gray.opacity(0.4))
            
            VStack(alignment: .leading, spacing: 4) {
                NavigationLink(destination: ExerciseHistoryView(exerciseName: exercise.name)) {
                    Text(LocalizationHelper.shared.translateName(exercise.name))
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                Group {
                    switch exercise.type {
                    case .strength:
                        let convertedWeight = unitsManager.convertFromKilograms(exercise.firstSetWeight)
                        Text("\(exercise.setsCount) sets x \(exercise.firstSetReps) reps • \(Int(convertedWeight)) \(unitsManager.weightUnitString())")
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
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
                exerciseToEdit = exercise
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Button {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
                if let idx = vm.exercises.firstIndex(where: { $0.id == exercise.id }) {
                    exercisesToDelete = IndexSet(integer: idx)
                    showDeleteExerciseAlert = true
                }
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    private var deleteButtonSection: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            HStack {
                Spacer()
                Image(systemName: "trash")
                Text(LocalizedStringKey("Delete Template"))
                Spacer()
            }
            .font(.headline)
            .padding(.vertical, 16)
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - Logic Helpers
    
    private func savePreset() async {
        await presetService.savePreset(preset: preset, name: vm.name, icon: vm.selectedIcon, folderName: preset?.folderName, exercises: vm.exercises)
        dismiss()
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Inner Exercise Editor ViewModel
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

// MARK: - Inner Exercise Editor View
struct PresetExerciseEditor: View {
    var exercise: Exercise
    var onSave: (Exercise) -> Void
    
    @Environment(\.dismiss) var dismiss
    @Environment(UnitsManager.self) var unitsManager
    @State private var vm = PresetExerciseFormViewModel()
    @State private var showValidationAlert = false
    
    var body: some View {
        NavigationStack {
            // 1. УБРАЛИ ZStack. Используем чистый ScrollView
            ScrollView {
                VStack(spacing: 24) {
                    Text(LocalizationHelper.shared.translateName(exercise.name))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    VStack(spacing: 16) {
                        switch exercise.type {
                        case .strength: strengthConfig
                        case .cardio: cardioConfig
                        case .duration: durationConfig
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Небольшой отступ для визуального "воздуха", 120 больше не нужно
                    Spacer(minLength: 20)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            // 2. ИСПОЛЬЗУЕМ safeAreaInset для кнопки
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                } label: {
                    Text(LocalizedStringKey("Save Changes"))
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(20)
                        .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .padding(.top, 24) // Отступ от контента до кнопки
                .background(
                    // Плавный градиент, скрывающий уходящий под кнопку контент
                    LinearGradient(
                        colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemGroupedBackground).opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .ignoresSafeArea()
                )
            }
            .navigationTitle(LocalizedStringKey("Configure Preset"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .onAppear {
                vm.load(from: exercise)
            }
            .alert(LocalizedStringKey("Invalid Input"), isPresented: $showValidationAlert) {
                Button(LocalizedStringKey("OK"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey(vm.validationErrorMessage ?? "Unknown error"))
            }
        }
    }
    
    // MARK: - Config Subviews
    
    @ViewBuilder
    private var strengthConfig: some View {
        customStepper(title: "Sets", value: $vm.setsCount, range: 1...20)
        customStepper(title: "Reps", value: $vm.repsCount, range: 0...100)
        customTextFieldRow(title: "Weight (\(unitsManager.weightUnitString()))", value: Binding(
            get: { unitsManager.convertFromKilograms(vm.weightValue) },
            set: { vm.weightValue = unitsManager.convertToKilograms($0 ?? 0) }
        ))
    }
    
    @ViewBuilder
    private var cardioConfig: some View {
        customTextFieldRow(
            title: "Distance (\(unitsManager.distanceUnitString()))",
            value: Binding(get: {
                if let d = vm.distanceValue { return unitsManager.convertFromMeters(d) }
                return 0
            }, set: { newValue in
                vm.distanceValue = unitsManager.convertToMeters(newValue ?? 0)
            })
        )
        customTimeRow(title: "Duration")
    }
    
    @ViewBuilder
    private var durationConfig: some View {
        customStepper(title: "Sets", value: $vm.setsCount, range: 1...10)
        customTimeRow(title: "Time per set")
    }
    
    // MARK: - Custom Controls
    
    private func customStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value.wrappedValue > range.lowerBound ? .blue : .gray.opacity(0.3))
                }
                
                Text("\(value.wrappedValue)")
                    .font(.title3)
                    .bold()
                    .frame(minWidth: 35, alignment: .center)
                
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value.wrappedValue < range.upperBound ? .blue : .gray.opacity(0.3))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    private func customTextFieldRow(title: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            ClearableTextField(placeholder: "0", value: value)
                .frame(width: 90)
                .font(.headline)
                .padding(.vertical, 4)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    private func customTimeRow(title: String) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                TextField("0", value: $vm.minutes, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .frame(width: 50)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                Text(LocalizedStringKey("min"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("0", value: $vm.seconds, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .frame(width: 50)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .onChange(of: vm.seconds) { _, newValue in
                        let clampedSeconds = max(0, min(newValue, 59))
                        if clampedSeconds != newValue {
                            vm.seconds = clampedSeconds
                        }
                    }
                
                Text(LocalizedStringKey("sec"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Logic
    
    private func save() {
        guard vm.validate(for: exercise.type, unitsManager: unitsManager) else {
            showValidationAlert = true
            return
        }
        
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        
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
        
        exercise.replaceAllSets(with: newSets)
        
        onSave(exercise)
        dismiss()
    }
}

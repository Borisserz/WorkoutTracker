//
//  PresetEditorView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//
//  Редактор шаблона тренировки (Preset).
//  Позволяет:
//  1. Задать имя и иконку шаблона.
//  2. Добавить/удалить упражнения.
//  3. Настроить параметры упражнений (целевые сеты, повторы).
//

internal import SwiftUI

// MARK: - Main Editor View

struct PresetEditorView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WorkoutViewModel
    
    // Если nil - создаем новый, иначе - редактируем
    @State var preset: WorkoutPreset?
    
    // Локальный стейт формы
    @State private var name: String = ""
    @State private var selectedIcon: String = "img_default"
    @State private var exercises: [Exercise] = []
    
    // Управление модальными окнами
    @State private var showExerciseSelector = false
    @State private var exerciseToEdit: Exercise?
    @State private var showDeleteAlert = false
    
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
            .navigationTitle(preset == nil ? "New Template" : "Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePreset()
                    }
                    .disabled(name.isEmpty || exercises.isEmpty)
                }
            }
            // Алерт удаления
            .alert("Delete Template?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let p = preset {
                        viewModel.deletePreset(p)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete '\(name)'? This action cannot be undone.")
            }
            // Инициализация
            .onAppear {
                if let p = preset {
                    name = p.name
                    selectedIcon = p.icon
                    exercises = p.exercises
                }
            }
            // Добавление упражнения
            .sheet(isPresented: $showExerciseSelector) {
                ExerciseSelectionView(selectedExercises: $exercises)
            }
            // Редактирование упражнения
            .sheet(item: $exerciseToEdit) { ex in
                PresetExerciseEditor(exercise: ex) { updatedEx in
                    if let index = exercises.firstIndex(where: { $0.id == ex.id }) {
                        exercises[index] = updatedEx
                    }
                    exerciseToEdit = nil
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        Section(header: Text("Template Info")) {
            TextField("Template Name", text: $name)
            
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
                                    .stroke(selectedIcon == iconName ? Color.blue : Color.clear, lineWidth: 3)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation { selectedIcon = iconName }
                            }
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    private var exerciseListSection: some View {
        Section(header: Text("Exercises")) {
            if exercises.isEmpty {
                Text("No exercises yet. Tap + to add.")
                    .italic()
                    .foregroundColor(.secondary)
            }
            
            ForEach(exercises) { exercise in
                HStack {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey(exercise.name)).font(.headline)
                        
                        Group {
                            switch exercise.type {
                            case .strength:
                                Text("\(exercise.sets) x \(exercise.reps) • \(Int(exercise.weight))kg")
                            case .cardio:
                                let dist = exercise.distance ?? 0
                                let time = exercise.timeSeconds ?? 0
                                Text("\(String(format: "%.2f", dist)) km • \(formatTime(time))")
                            case .duration:
                                let time = exercise.timeSeconds ?? 0
                                Text("\(exercise.sets) sets • \(formatTime(time))")
                            }
                        }
                        .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button {
                        exerciseToEdit = exercise
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .onDelete { indexSet in
                exercises.remove(atOffsets: indexSet)
            }
            
            Button {
                showExerciseSelector = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
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
                    Text("Delete Template")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    private func savePreset() {
        let newPreset = WorkoutPreset(
            id: preset?.id ?? UUID(),
            name: name,
            icon: selectedIcon,
            exercises: exercises
        )
        viewModel.updatePreset(newPreset)
        dismiss()
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Inner Exercise Editor

struct PresetExerciseEditor: View {
    @State var exercise: Exercise
    var onSave: (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
    
    // Локальное время
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    
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
                
                Button("Save Changes") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Configure Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                let total = exercise.timeSeconds ?? 0
                minutes = total / 60
                seconds = total % 60
            }
        }
    }
    
    // MARK: - Config Subviews
    
    @ViewBuilder
    private var strengthConfig: some View {
        Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...20)
        Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...100)
        HStack {
            Text("Weight (kg):")
            TextField("0", value: $exercise.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
    
    @ViewBuilder
    private var cardioConfig: some View {
        HStack {
            Text("Distance (km):")
            TextField("0", value: Binding(get: { exercise.distance ?? 0 }, set: { exercise.distance = $0 }), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
        timePickerRow(label: "Duration")
    }
    
    @ViewBuilder
    private var durationConfig: some View {
        Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...10)
        timePickerRow(label: "Time per set")
    }
    
    private func timePickerRow(label: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: $minutes, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
            Text("min")
            TextField("0", value: $seconds, format: .number)
                .frame(width: 40).multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .background(Color.gray.opacity(0.1)).cornerRadius(5)
            Text("sec")
        }
    }
    
    // MARK: - Logic
    
    private func save() {
        let total = (minutes * 60) + seconds
        exercise.timeSeconds = total > 0 ? total : nil
        
        if exercise.type == .cardio { exercise.sets = 1 }
        
        if exercise.type != .strength {
            exercise.weight = 0
            exercise.reps = 0
        }
        
        // Перегенерируем setsList, чтобы шаблон был консистентным
        var newSets: [WorkoutSet] = []
        let setsCount = max(1, exercise.sets)
        
        for i in 1...setsCount {
            newSets.append(WorkoutSet(
                index: i,
                weight: exercise.type == .strength ? exercise.weight : nil,
                reps: exercise.type == .strength ? exercise.reps : nil,
                distance: exercise.type == .cardio ? exercise.distance : nil,
                time: exercise.timeSeconds,
                isCompleted: false,
                type: .normal
            ))
        }
        exercise.setsList = newSets
        
        onSave(exercise)
        dismiss()
    }
}

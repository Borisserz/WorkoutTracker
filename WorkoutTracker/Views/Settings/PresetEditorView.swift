//
//  PresetEditorView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI

struct PresetEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // Если nil - создаем новый, если есть - редактируем
    @State var preset: WorkoutPreset?
    
    // Временные данные для формы
    @State private var name: String = ""
    @State private var selectedIcon: String = "img_default"
    @State private var exercises: [Exercise] = []
    
    @State private var showExerciseSelector = false
    @State private var exerciseToEdit: Exercise?
    @State private var showDeleteAlert = false // Для подтверждения удаления
    
    // --- ВОТ ЗДЕСЬ ПУЛ ИКОНОК ---
    // Просто добавляй названия картинок из Assets в этот список через запятую
    let availableIcons = [
        "img_default",
        "img_chest", "img_chest2",
        "img_back", "img_back2",
        "img_legs", "img_legs2",
        "img_arms",
        "battle-rope",
        "dumbbell",
        "exercise-2",
        "gym-4",
        
        // "img_new_icon",  <-- Твой новый файл
        // "img_cardio"     <-- Еще один
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. Настройки заголовка
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
                                    .onTapGesture {
                                        selectedIcon = iconName
                                    }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                // 2. Список упражнений
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
                                Text("\(exercise.sets) x \(exercise.reps) • \(Int(exercise.weight))kg")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            // Кнопка редактирования (Без RPE)
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
                
                // 3. КНОПКА УДАЛЕНИЯ (Только если редактируем существующий)
                if let existingPreset = preset {
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
            // Загрузка данных
            .onAppear {
                if let p = preset {
                    name = p.name
                    selectedIcon = p.icon
                    exercises = p.exercises
                }
            }
            // Выбор упражнения
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
    
    func savePreset() {
        let newPreset = WorkoutPreset(
            id: preset?.id ?? UUID(),
            name: name,
            icon: selectedIcon,
            exercises: exercises
        )
        viewModel.updatePreset(newPreset)
        dismiss()
    }
}

// Вспомогательный редактор (без изменений)
struct PresetExerciseEditor: View {
    @State var exercise: Exercise
    var onSave: (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(exercise.name)) {
                    Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...20)
                    Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...100)
                    
                    HStack {
                        Text("Weight (kg):")
                        TextField("0", value: $exercise.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Button("Save Changes") {
                    onSave(exercise)
                    dismiss()
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
        }
    }
}

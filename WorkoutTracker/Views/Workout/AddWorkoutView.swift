internal import SwiftUI
import ActivityKit

struct AddWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WorkoutViewModel // Нужен доступ к presets
    @Binding var workouts: [Workout]
    
    @State private var title = ""
    @State private var selectedPreset: WorkoutPreset? // Храним выбранный пресет
    
    var body: some View {
        NavigationStack {
            Form {
                // Секция 1: Имя
                Section(header: Text("Workout Name")) {
                    TextField("E.g. Evening Pump", text: $title)
                }
                
                // Секция 2: Выбор шаблона
                Section(header: Text("Choose Template"),
                        footer: Text("You can change your prepared workouts in the settings..")) {
                    // Кнопка "Без шаблона" (Empty)
                    Button {
                        selectPreset(nil)
                    } label: {
                        HStack {
                            Image(systemName: "plus.square.dashed")
                                .font(.title2)
                                .foregroundColor(.gray)
                            VStack(alignment: .leading) {
                                Text("Empty Workout").foregroundColor(.primary)
                                Text("Start from scratch").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedPreset == nil {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Список пресетов из ViewModel
                    ForEach(viewModel.presets) { preset in
                        Button {
                            selectPreset(preset)
                        } label: {
                            HStack {
                              
                                Image(preset.icon)
                                    .resizable()                // Разрешаем менять размер
                                    .aspectRatio(contentMode: .fit) // Сохраняем пропорции
                                    .frame(width: 50, height: 50)   // Задаем красивый размер квадрата
                                    .cornerRadius(8)            // Скругляем углы (по желанию)
                                    .shadow(radius: 2)          // Небольшая тень
                                // ---------------------------------------

                                VStack(alignment: .leading) {
                                    Text(preset.name).foregroundColor(.primary)
                                    Text("\(preset.exercises.count) exercises").font(.caption).foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedPreset?.id == preset.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Секция 3: Предпросмотр (какие упражнения добавятся)
                if let preset = selectedPreset {
                    Section(header: Text("Includes")) {
                        ForEach(preset.exercises) { ex in
                            Text(ex.name)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Start Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    // Кнопка активна, если есть имя ИЛИ выбран пресет
                    Button("Start Now") {
                        startWorkout()
                    }
                    .disabled(title.isEmpty && selectedPreset == nil)
                }
            }
            .onAppear {
                // При открытии ставим имя по умолчанию, если пусто
                if title.isEmpty {
                    setFormattedDateName()
                }
            }
        }
    }
    
    // Логика выбора пресета
    func selectPreset(_ preset: WorkoutPreset?) {
        withAnimation {
            selectedPreset = preset
            // Если выбрали пресет, автоматически меняем название тренировки на название пресета
            if let p = preset {
                title = p.name
            } else {
                // Если сбросили, возвращаем дату
                setFormattedDateName()
            }
        }
    }
    
    func setFormattedDateName() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE Workout" // "Friday Workout"
        title = formatter.string(from: Date())
    }
    
    func startWorkout() {
        // 1. Формируем список упражнений
        var exercisesToAdd: [Exercise] = []
        
        if let preset = selectedPreset {
            // ВАЖНО: Создаем копии упражнений с НОВЫМИ ID.
            // Иначе, если ты поменяешь вес в тренировке, это может сломать логику истории,
            // если ID будут дублироваться.
            exercisesToAdd = preset.exercises.map { ex in
                Exercise(
                    id: UUID(), // Генерируем новый ключ
                    name: ex.name,
                    muscleGroup: ex.muscleGroup,
                    sets: ex.sets,
                    reps: ex.reps,
                    weight: ex.weight,
                    effort: ex.effort
                )
            }
        }
        
        // 2. Создаем тренировку
        let newWorkout = Workout(
            title: title.isEmpty ? "New Workout" : title,
            date: Date(),
            endTime: nil,
            exercises: exercisesToAdd // <-- Вставляем упражнения пресета (или пустоту)
        )
        
        workouts.insert(newWorkout, at: 0)
        
        // --- 3. ЗАПУСК LIVE ACTIVITY (твой код) ---
        let attributes = WorkoutActivityAttributes(workoutTitle: title)
        let state = WorkoutActivityAttributes.ContentState(startTime: Date())
        
        do {
            let activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            print("Live Activity started with ID: \(activity.id)")
        } catch (let error) {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
        
        dismiss()
    }
}

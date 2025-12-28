internal import SwiftUI

struct ExerciseView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @State private var showAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // Пробегаемся по всем категориям (Chest, Back...), сортируем по алфавиту
                ForEach(viewModel.combinedCatalog.keys.sorted(), id: \.self) { group in
                    // ИСПРАВЛЕНИЕ ЗДЕСЬ: Добавлена закрывающая скобка ')'
                    Section(header: Text(LocalizedStringKey(group))) {
                        
                        // Получаем список упражнений для группы и СОРТИРУЕМ его
                        let exercises = viewModel.combinedCatalog[group]?.sorted() ?? []
                        
                        ForEach(exercises, id: \.self) { exerciseName in
                            NavigationLink(destination: ExerciseHistoryView(exerciseName: exerciseName, allWorkouts: viewModel.workouts)) {
                                HStack {
                                    // Здесь тоже используем LocalizedStringKey для перевода
                                    Text(LocalizedStringKey(exerciseName))
                                    Spacer()
                                    // Если упражнение добавлено пользователем — показываем иконку
                                    if isCustom(name: exerciseName) {
                                        Image(systemName: "person.crop.circle")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                    }
                                }
                            }
                            // Запрещаем удаление, если это НЕ пользовательское упражнение
                            .deleteDisabled(!isCustom(name: exerciseName))
                        }
                        // Подключаем стандартный механизм удаления к списку
                        .onDelete { indexSet in
                            deleteExercise(at: indexSet, in: group, exercises: exercises)
                        }
                    }
                }
            }
            .navigationTitle("Exercise Catalog") // Этот заголовок тоже должен быть в Localizable
            .toolbar {
                // 1. Кнопка ПЛЮС — СЛЕВА
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                
                // 2. Кнопка EDIT — СПРАВА
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddNewExerciseView()
            }
        }
    }
    
    // --- Логика ---
    
    func isCustom(name: String) -> Bool {
        return viewModel.customExercises.contains(where: { $0.name == name })
    }
    
    func deleteExercise(at offsets: IndexSet, in group: String, exercises: [String]) {
        offsets.forEach { index in
            let nameToDelete = exercises[index]
            if isCustom(name: nameToDelete) {
                viewModel.deleteCustomExercise(name: nameToDelete, category: group)
            }
        }
    }
}

#Preview {
    ExerciseView()
        .environmentObject(WorkoutViewModel())
}

//
//  WorkoutDetailView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI
import Charts
import Combine
import ActivityKit
import Foundation

struct WorkoutDetailView: View {
    @Binding var workout: Workout
    @EnvironmentObject var viewModel: WorkoutViewModel
    @State private var shareImage: Image?
    @State private var showSupersetBuilder = false
    @State private var supersetToEdit: Exercise? // Для редактирования
    // --- СОСТОЯНИЯ ---
    @State private var showExerciseSelection = false
    @State private var timeElapsed: String = "0:00"
    
    // Состояние для редактирования упражнения
    @State private var exerciseToEdit: Exercise?
    @State private var showShareSheet = false
        @State private var shareItems: [Any] = []
    // Состояние для настройки сравнения (Арбузы/Слоны)
    @State private var showComparisonSettings = false
    
    var flattenedExercises: [Exercise] {
        workout.exercises.flatMap { exercise in
            exercise.isSuperset ? exercise.subExercises : [exercise]
        }
    }
    
    // --- ГЕНЕРАЦИЯ КАРТИНКИ ---
       @MainActor
       func generateAndShare() {
           // 1. Создаем рендерер с нашей карточкой
           let renderer = ImageRenderer(content: WorkoutShareCard(workout: workout))
           renderer.scale = 3.0 // Высокое качество
           
           // 2. Получаем UIImage
           if let uiImage = renderer.uiImage {
               // 3. Кладем в массив для шеринга
               self.shareItems = [uiImage]
               // 4. Показываем меню
               self.showShareSheet = true
           }
       }
    
    // Вычисляем интенсивность нагрузки на каждую мышцу
    var muscleIntensityMap: [String: Int] {
        var counts = [String: Int]()
        
        for exercise in workout.exercises {
            // Если это супер-сет, проходимся по его детям
            if exercise.isSuperset {
                for sub in exercise.subExercises {
                    let muscles = MuscleMapping.getMuscles(for: sub.name, group: sub.muscleGroup)
                    for muscleSlug in muscles {
                        counts[muscleSlug, default: 0] += 1
                    }
                }
            } else {
                // Обычное упражнение
                let muscles = MuscleMapping.getMuscles(for: exercise.name, group: exercise.muscleGroup)
                for muscleSlug in muscles {
                    counts[muscleSlug, default: 0] += 1
                }
            }
        }
        
        return counts
    }
    
    
    
    var body: some View {
          // УБРАЛИ ZStack, вернули просто ScrollView как главный контейнер
          ScrollView {
              VStack(alignment: .leading, spacing: 20) {
                  
                  headerSection
                  
                  if workout.isActive {
                      Button(action: finishWorkout) {
                          Text("Finish Workout")
                              .font(.headline)
                              .frame(maxWidth: .infinity)
                              .padding()
                              .background(Color.red)
                              .foregroundColor(.white)
                              .cornerRadius(12)
                              .shadow(radius: 5)
                      }
                  }else {// --- ИСПРАВЛЕННАЯ КНОПКА ПОДЕЛИТЬСЯ ---
                      Button {
                          generateAndShare()
                      } label: {
                          HStack {
                              Image(systemName: "square.and.arrow.up")
                              Text("Share Result")
                          }
                          .font(.headline)
                          .frame(maxWidth: .infinity)
                          .padding()
                          .background(Color.blue)
                          .foregroundColor(.white)
                          .cornerRadius(12)
                          .shadow(radius: 5)
                      }
                  }
                  
                  Divider().padding(.vertical, 5)
                  
                  HStack {
                      Text("Exercises").font(.title2).bold()
                      Spacer()
                      
                      // --- КНОПКА ЗАПУСКА ТАЙМЕРА ---
                      // Показываем ТОЛЬКО если тренировка активна (workout.isActive)
                      if workout.isActive {
                          Button {
                              // Запускаем на 30 секунд
                              viewModel.startRestTimer()
                          } label: {
                              Image(systemName: "timer")
                                  .font(.headline)
                                  .padding(8)
                                  .background(Color.orange.opacity(0.1))
                                  .foregroundColor(.orange)
                                  .cornerRadius(8)
                          }
                      }
                      
                      Button {
                          showSupersetBuilder = true
                      } label: {
                          Label("Superset", systemImage: "plus")
                              .font(.caption).bold()
                              .padding(8)
                              .background(Color.purple.opacity(0.1))
                              .foregroundColor(.purple)
                              .cornerRadius(8)
                      }
                      .disabled(!workout.isActive)
                      
                      Button { showExerciseSelection = true } label: {
                          Label("Exercise", systemImage: "plus")
                              .font(.caption).bold()
                              .padding(8)
                              .background(Color.blue.opacity(0.1))
                              .cornerRadius(8)
                      }
                      .disabled(!workout.isActive)
                  }
                  
                  exerciseListSection
                  chartSection
                  muscleHeatmapSection
                  
                  if !workout.exercises.isEmpty {
                      FunFactView(workout: workout, showSettings: $showComparisonSettings)
                  }
                  
                  // Отступ снизу, чтобы глобальный таймер не перекрывал контент
                  Spacer(minLength: 80)
              }
              .padding()
          }
          .navigationTitle(workout.title)
        // --- ОТКРЫТИЕ МЕНЮ ПОДЕЛИТЬСЯ ---
               .sheet(isPresented: $showShareSheet) {
                   ActivityViewController(activityItems: shareItems)
                       .presentationDetents([.medium, .large])
               }
          // ... (Все твои .sheet и .onReceive оставляем без изменений) ...
          .sheet(isPresented: $showExerciseSelection) {
              ExerciseSelectionView(selectedExercises: $workout.exercises)
          }
          .sheet(item: $exerciseToEdit) { exerciseToSave in
               if let index = workout.exercises.firstIndex(where: { $0.id == exerciseToSave.id }) {
                   NavigationStack {
                       EditExerciseView(exercise: $workout.exercises[index])
                           .toolbar {
                               ToolbarItem(placement: .destructiveAction) {
                                   Button("Delete", role: .destructive) {
                                       workout.exercises.remove(at: index)
                                       exerciseToEdit = nil
                                   }
                               }
                           }
                   }
                   .presentationDetents([.medium, .large])
               }
           }
          .sheet(isPresented: $showComparisonSettings) {
              ComparisonSettingsView().presentationDetents([.medium])
          }
          .sheet(isPresented: $showSupersetBuilder) {
              SupersetBuilderView { newSuperset in
                  workout.exercises.append(newSuperset)
              }
          }
          .sheet(item: $supersetToEdit) { superset in
              SupersetBuilderView(existingSuperset: superset, onSave: { updatedSuperset in
                  if let index = workout.exercises.firstIndex(where: { $0.id == superset.id }) {
                      workout.exercises[index] = updatedSuperset
                  }
                  supersetToEdit = nil
              }, onDelete: {
                  if let index = workout.exercises.firstIndex(where: { $0.id == superset.id }) {
                      withAnimation { workout.exercises.remove(at: index) }
                  }
                  supersetToEdit = nil
              })
          }
          .onReceive(Foundation.Timer.publish(every: 1.0, on: RunLoop.main, in: RunLoop.Mode.common).autoconnect()) { _ in
              if workout.isActive { updateTimer() }
          }
          .onAppear(perform: updateTimer)
      }
      
        
        
        // Внутри struct WorkoutDetailView
        
        
        private var workoutImage: Image {
            if workout.exercises.isEmpty { return Image("img_default") }
            
            // 1. Считаем мышцы
            var counts: [String: Int] = [:]
            for exercise in workout.exercises {
                if exercise.isSuperset {
                    for sub in exercise.subExercises { counts[sub.muscleGroup, default: 0] += 1 }
                } else {
                    counts[exercise.muscleGroup, default: 0] += 1
                }
            }
            
            // 2. ИСПРАВЛЕНИЕ: Сортируем жестко
            // Сначала по количеству (кто больше), а если поровну — по алфавиту.
            // Это предотвратит скачки картинки при обновлении таймера.
            let sortedGroups = counts.sorted { (item1, item2) -> Bool in
                if item1.value == item2.value {
                    return item1.key < item2.key // При ничьей берем первую по алфавиту
                }
                return item1.value > item2.value // Иначе берем ту, где больше упражнений
            }
            
            let dominantGroup = sortedGroups.first?.key ?? "Default"
            
            // 3. Выбираем картинку
            let imageName: String
            switch dominantGroup {
            case "Chest": imageName = pickVariant(from: ["img_chest", "img_chest2"])
            case "Back": imageName = pickVariant(from: ["img_back", "img_back2"])
            case "Legs": imageName = pickVariant(from: ["img_legs", "img_legs2"])
            case "Arms": imageName = "img_arms"
            case "Shoulders": imageName = "img_shoulders"
            default: imageName = "img_default"
            }
            
            return Image(imageName)
        }
        
        // Стабильный выбор варианта на основе ID (никогда не меняется для одной тренировки)
        private func pickVariant(from options: [String]) -> String {
            guard !options.isEmpty else { return "img_default" }
            
            // Превращаем UUID строку в число (суммируем коды символов)
            // hashValue использовать нельзя, он меняется при перезапуске приложения!
            let stableHash = workout.id.uuidString.utf8.reduce(0) { Int($0) + Int($1) }
            
            let index = abs(stableHash) % options.count
            return options[index]
        }
        
        
        
        
        // ... (body и т.д.) ...
        
        // 2. ОБНОВЛЯЕМ HEADER SECTION
        private var headerSection: some View {
            VStack(spacing: 20) {
                // ... (верхняя часть с таймером остается без изменений) ...
                if workout.isActive {
                    HStack {
                        Label("Live Workout", systemImage: "record.circle")
                            .foregroundStyle(.red).bold().blinking()
                        Spacer()
                        Text(timeElapsed).font(.title2).monospacedDigit().bold()
                    }.padding().background(Color.red.opacity(0.1)).cornerRadius(12)
                } else {
                    HStack {
                        Image(systemName: "flag.checkered").foregroundColor(.green)
                        Text("Completed").bold()
                        Spacer()
                        Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }.padding().background(Color.green.opacity(0.1)).cornerRadius(12)
                }
                
                // --- ВОТ ТУТ МЕНЯЕМ КАРТИНКУ ---
                workoutImage
                    .resizable()                 // Разрешаем менять размер
                    .aspectRatio(contentMode: .fit) // Сохраняем пропорции
                    .frame(height: 200)          // Высота картинки (можно подстроить)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1)) // Легкий фон
                    .cornerRadius(12)
                    .shadow(radius: 5)           // Небольшая тень для красоты
                // -----------------------------
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Duration").font(.caption).foregroundColor(.secondary)
                        Text(workout.isActive ? timeElapsed : "\(workout.duration) min").font(.title2).bold()
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Avg Effort").font(.caption).foregroundColor(.secondary)
                        Text("\(workout.effortPercentage)%").font(.title2).bold()
                            .foregroundColor(effortColor(percentage: workout.effortPercentage))
                    }
                }.padding().background(Color.blue.opacity(0.05)).cornerRadius(10)
            }
        }
        
        private var exerciseListSection: some View {
            Group {
                if workout.exercises.isEmpty {
                    Text("No exercises added yet.")
                        .italic().foregroundColor(.secondary).padding(.vertical)
                } else {
                    VStack(spacing: 12) { // Чуть больше отступ между карточками
                        ForEach(workout.exercises) { exercise in
                            if exercise.isSuperset {
                                // --- ОТРИСОВКА СУПЕР-СЕТА ---
                                supersetCard(exercise)
                            } else {
                                // --- ОБЫЧНОЕ УПРАЖНЕНИЕ ---
                                singleExerciseRow(exercise)
                            }
                        }
                    }
                }
            }
        }
        
        // Вынесли обычное упражнение в функцию, чтобы не дублировать код
        private func singleExerciseRow(_ exercise: Exercise) -> some View {
            VStack(spacing: 0) {
                HStack {
                    NavigationLink(destination: ExerciseHistoryView(exerciseName: exercise.name, allWorkouts: viewModel.workouts)) {
                        ExerciseRowView(exercise: exercise)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if workout.isActive {
                        Button { exerciseToEdit = exercise } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2).foregroundColor(.blue).padding(.leading, 12)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray).font(.caption).padding(.leading, 8)
                    }
                }
                Divider()
            }
        }
        
        // Карточка Супер-сета
        private func supersetCard(_ superset: Exercise) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                // Заголовок Супер-сета
                HStack {
                    Text("SUPERSET")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Общая усталость
                    Text("Total RPE \(superset.effort)")
                        .font(.caption2)
                        .bold()
                        .padding(4)
                        .background(effortColor(percentage: superset.effort * 10).opacity(0.2))
                        .foregroundColor(effortColor(percentage: superset.effort * 10))
                        .cornerRadius(4)
                    
                    // Кнопка редактирования всего суперсета
                    if workout.isActive {
                        Button { supersetToEdit = superset } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2).foregroundColor(.purple)
                        }
                    }
                }
                .padding(.bottom, 8)
                
                // Список упражнений ВНУТРИ суперсета
                ForEach(superset.subExercises.indices, id: \.self) { index in
                    let subEx = superset.subExercises[index]
                    HStack {
                        // Линия связи
                        Rectangle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(width: 2)
                            .padding(.vertical, -4) // Чтобы линия была сплошной
                        
                        VStack(alignment: .leading) {
                            // Имя - ссылка на историю
                            NavigationLink(destination: ExerciseHistoryView(exerciseName: subEx.name, allWorkouts: viewModel.workouts)) {
                                Text(subEx.name).font(.headline).foregroundColor(.primary)
                            }
                            
                            Text("\(subEx.sets)s x \(subEx.reps)r • \(Int(subEx.weight))kg")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 4)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    
                    if index < superset.subExercises.count - 1 {
                        Divider().padding(.leading, 10)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
        
        private var chartSection: some View {
            Group {
                if !workout.exercises.isEmpty {
                    Text("Analysis")
                        .font(.title2)
                        .bold()
                        .padding(.top)
                    
                    // Используем flattenedExercises (чтобы разбить супер-сеты)
                    Chart {
                        ForEach(flattenedExercises) { exercise in
                            BarMark(
                                x: .value("Exercise", exercise.name), // Имя по оси X
                                y: .value("Weight", exercise.weight)  // Вес по оси Y
                            )
                            .foregroundStyle(Color.blue.gradient)
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: 200)
                    // .chartScrollableAxes(.horizontal) <--- Я УБРАЛ ЭТУ СТРОКУ
                    // Теперь график будет стараться уместить всё в одну ширину
                    
                    // Дополнительная настройка: если названий много,
                    // SwiftUI может скрыть некоторые подписи, чтобы не было каши.
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisTick()
                            AxisValueLabel(collisionResolution: .greedy) // Пытаться показать как можно больше
                        }
                    }
                }
            }
        }
        private var muscleHeatmapSection: some View {
            VStack(alignment: .leading) {
                Text("Body Status")
                    .font(.title2)
                    .bold()
                    .padding(.top)
                
                VStack {
                    // ПЕРЕДАЕМ СЛОВАРЬ ИНТЕНСИВНОСТИ
                    BodyHeatmapView(muscleIntensities: muscleIntensityMap)
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
            }
        }
        
        // --- ЛОГИКА ---
        
        private func updateTimer() {
            let diff = Date().timeIntervalSince(workout.date)
            let hours = Int(diff) / 3600
            let minutes = (Int(diff) / 60) % 60
            let seconds = Int(diff) % 60
            timeElapsed = hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
        }
        
        private func finishWorkout() {
            workout.endTime = Date()
            viewModel.progressManager.addXP(for: workout)
            
            
            NotificationManager.shared.scheduleNotifications(after: workout)
            
            Task {
                for activity in Activity<WorkoutActivityAttributes>.activities {
                    await activity.end(dismissalPolicy: .after(Date().addingTimeInterval(5)))
                }
            }
        }
        
        private func effortColor(percentage: Int) -> Color {
            if percentage > 80 { return .red }
            if percentage > 50 { return .orange }
            return .green
        }
    }


// --- ВСПОМОГАТЕЛЬНЫЕ КОМПОНЕНТЫ (FunFact, Comparison и т.д.) ---

struct FunFactView: View {
    let workout: Workout
        @Binding var showSettings: Bool
        
        @AppStorage("comparisonName") private var comparisonName = "Watermelons"
        @AppStorage("comparisonWeight") private var comparisonWeight = 8.0
        
        var totalVolume: Double {
            // ИСПОЛЬЗУЕМ НОВОЕ СВОЙСТВО computedVolume
            workout.exercises.reduce(0.0) { sum, exercise in
                sum + exercise.computedVolume
            }
        }
    
    var comparisonCount: Double {
        if comparisonWeight <= 0 { return 0 }
        return totalVolume / comparisonWeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🏋️ Total Volume")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text("You lifted \(Int(totalVolume)) kg!")
                .font(.title2)
                .bold()
            
            Divider()
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("That's approximately")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(comparisonCount, format: .number.precision(.fractionLength(1)))")
                            .font(.title3)
                            .fontWeight(.heavy)
                    }
                    Text("Way to go, champion! 🥇")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                }
                
                Spacer()
                
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.top, 10)
    }
}

struct ComparisonSettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("comparisonName") private var comparisonName = "Watermelons 🍉"
       @AppStorage("comparisonWeight") private var comparisonWeight = 8.0
       
       // Массив теперь использует String (для Hashable)
       let presets: [(name: String, weight: Double, icon: String)] = [
           ("Watermelons 🍉", 8.0, "🍉"),
           ("African Elephants 🐘", 6000.0, "🐘"),
           ("Toyota Camrys 🚗", 1500.0, "🚗"),
           ("Adult Pandas 🐼", 100.0, "🐼"),
           ("Gold Bars 🧈", 12.4, "🧈"),
           ("SpaceX Starships 🚀", 5000000.0, "🚀")
       ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Custom Comparison")) {
                    TextField("Object Name (e.g. Pizzas)", text: $comparisonName)
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("Weight", value: $comparisonWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Quick Presets")) {
                    ForEach(presets, id: \.name) { preset in
                        Button {
                            comparisonName = preset.name
                            comparisonWeight = preset.weight
                            dismiss()
                        } label: {
                            HStack {
                                Text(preset.icon).font(.title2)
                                VStack(alignment: .leading) {
                                    Text(LocalizedStringKey(preset.name)).foregroundColor(.primary)
                                    Text("\(Int(preset.weight)) kg").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if comparisonName == preset.name {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Compare With...")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise
    func effortColor(value: Int) -> Color {
        switch value {
        case 1...4: return .green
        case 5...7: return .orange
        case 8...10: return .red
        default: return .blue
        }
    }
    var body: some View {
        HStack {
            Rectangle().frame(width: 4).foregroundColor(effortColor(value: exercise.effort)).cornerRadius(2)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(exercise.name)).font(.headline).foregroundColor(.primary)
                HStack {
                    Text("\(exercise.sets)s x \(exercise.reps)r • \(String(format: "%.0f", exercise.weight))kg")
                        .font(.subheadline).foregroundColor(.secondary)
                    Text("RPE \(exercise.effort)").font(.caption2).bold().padding(4)
                        .background(effortColor(value: exercise.effort).opacity(0.2))
                        .foregroundColor(effortColor(value: exercise.effort)).cornerRadius(4)
                }
            }
            Spacer()
        }.padding(.vertical, 8).contentShape(Rectangle())
    }
}

struct Blinking: ViewModifier {
    @State private var isOn = false
    func body(content: Content) -> some View {
        content.opacity(isOn ? 1 : 0.5).onAppear {
            withAnimation(Animation.easeInOut(duration: 1).repeatForever()) { isOn = true }
        }
    }
}
extension View { func blinking() -> some View { modifier(Blinking()) } }

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: .constant(
            Workout(title: "Live Test", date: Date(), exercises: [
                Exercise(name: "Bench Press", muscleGroup: "Chest", sets: 3, reps: 10, weight: 80, effort: 9)
            ])
        )).environmentObject(WorkoutViewModel())
    }
}

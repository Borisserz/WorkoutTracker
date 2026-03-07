internal import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) var dismiss
    
    // Данные базы напрямую из SwiftData
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @AppStorage("userName") private var userName = "Fitness Enthusiast"
    @AppStorage("userBodyWeight") private var userBodyWeight = 75.0  // Хранится в кг
    @AppStorage("userGender") private var userGender = "male" // "male" or "female"
    
    @StateObject private var unitsManager = UnitsManager.shared
    @StateObject private var weightManager = WeightTrackingManager.shared
    
    // Состояния для редактирования
    @State private var isEditingName = false
    @State private var isEditingWeight = false
    @State private var tempName = ""
    @State private var tempWeight = ""
    
    @State private var selectedAchievement: Achievement?
    @State private var showingWeightHistory = false
    
    // Кешированные значения для производительности
    @State private var cachedAchievements: [Achievement] = []
    @State private var cachedPersonalRecords: [WorkoutViewModel.BestResult] = []
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    // Функция для обновления кеша
    private func updateCache() {
        let streak = StatisticsManager.calculateWorkoutStreak(workouts: workouts)
        cachedAchievements = AchievementCalculator.calculateAchievements(workouts: workouts, streak: streak)
        cachedPersonalRecords = StatisticsManager.getAllPersonalRecords(workouts: workouts)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. HEADER (Аватар, Имя, Вес)
                    VStack(spacing: 15) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                            .shadow(radius: 5)
                        
                        VStack(spacing: 8) {
                            // ИМЯ (Кликабельное)
                            HStack {
                                Text(userName).font(.title2).bold()
                                Image(systemName: "pencil").font(.caption).foregroundColor(.blue)
                            }
                            .onTapGesture {
                                tempName = userName
                                isEditingName = true
                            }
                            
                            // ВЕС под ником (Кликабельный)
                            let convertedWeight = unitsManager.convertFromKilograms(userBodyWeight)
                            Text("\(LocalizationHelper.shared.formatDecimal(convertedWeight)) \(unitsManager.weightUnitString())")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .onTapGesture {
                                    tempWeight = LocalizationHelper.shared.formatDecimal(convertedWeight)
                                    isEditingWeight = true
                                }
                            
                            // Кнопка просмотра истории веса
                            Button {
                                showingWeightHistory = true
                            } label: {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                    Text(LocalizedStringKey("View Weight History"))
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // ПЕРЕКЛЮЧАТЕЛЬ ПОЛА
                            Picker(LocalizedStringKey("Gender"), selection: $userGender) {
                                Text(LocalizedStringKey("Male")).tag("male")
                                Text(LocalizedStringKey("Female")).tag("female")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                            
                        }
                    }
                    .padding(.top, 20)
                    
                    // 2. ачивки
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("Achievements")).font(.title3).bold().padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(cachedAchievements) { achievement in
                                AchievementBadge(achievement: achievement).onTapGesture {
                                   selectedAchievement = achievement
                                    
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                        }
                    }
                    .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    // 3. рекорды
                    if !cachedPersonalRecords.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text(LocalizedStringKey("Personal Records")).font(.title3).bold().padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                ForEach(cachedPersonalRecords) { record in
                                    HStack {
                                        // Иконка типа
                                        Image(systemName: getIcon(for: record.type))
                                            .foregroundColor(getColor(for: record.type))
                                            .frame(width: 30)
                                        
                                        Text(LocalizedStringKey(record.exerciseName))
                                            .font(.body)
                                        
                                        Spacer()
                                        
                                        Text(record.value)
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    }
                                    .padding()
                                    
                                    if record.id != cachedPersonalRecords.last?.id {
                                        Divider().padding(.leading, 50)
                                    }
                                }
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    } else {
                        Text(LocalizedStringKey("Complete workouts to see your records!"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle(LocalizedStringKey("Profile"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
            }
            // алерты
            .alert(LocalizedStringKey("Change Name"), isPresented: $isEditingName) {
                TextField(LocalizedStringKey("Name"), text: $tempName)
                Button(LocalizedStringKey("Save")) { if !tempName.isEmpty { userName = tempName } }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            }
            .alert(LocalizedStringKey("Update Body Weight"), isPresented: $isEditingWeight) {
                TextField(LocalizedStringKey("Weight (\(unitsManager.weightUnitString()))"), text: $tempWeight).keyboardType(.decimalPad)
                Button(LocalizedStringKey("Save")) { 
                    if let val = Double(tempWeight) { 
                        // Конвертируем из выбранных единиц в кг для сохранения
                        let weightInKg = unitsManager.convertToKilograms(val)
                        userBodyWeight = weightInKg
                        
                        // Автоматически сохраняем запись в историю веса
                        weightManager.addWeightEntry(weight: weightInKg, date: Date())
                    }
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) { }
            }
            .sheet(isPresented: $showingWeightHistory) {
                WeightHistoryView()
            }
            .onAppear {
                // Инициализируем первый вес из профиля, если истории еще нет
                weightManager.initializeFirstWeightIfNeeded(from: userBodyWeight)
                // Обновляем кеш при появлении view
                updateCache()
            }
            .onChange(of: workouts.count) { _, _ in
                // Обновляем кеш когда изменяется количество тренировок
                updateCache()
            }
            .alert(item: $selectedAchievement) { achievement in
                Alert(
                    title: Text(achievement.title),
                    message: Text(achievement.description + "\n\n" + (achievement.isUnlocked ? "✅ Unlocked" : "🔒 Locked")),
                    dismissButton: .default(Text(LocalizedStringKey("Cool!")))
                )
            }
        }
    }
    
    // Вспомогательные функции для иконок
    func getIcon(for type: ExerciseType) -> String {
        switch type {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .duration: return "stopwatch.fill"
        }
    }
    
    func getColor(for type: ExerciseType) -> Color {
        switch type {
        case .strength: return .blue
        case .cardio: return .orange
        case .duration: return .purple
        }
    }
}

// AchievementBadge без изменений (но должен быть в проекте)
struct AchievementBadge: View {
    let achievement: Achievement
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.color.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 75, height: 75)
                Image(systemName: achievement.icon)
                    .font(.largeTitle)
                    .foregroundColor(achievement.isUnlocked ? achievement.color : .gray)
            }
            .overlay(alignment: .bottomTrailing) {
                if !achievement.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption).foregroundColor(.white)
                        .padding(5).background(Circle().fill(Color.gray))
                        .offset(x: 0, y: 5)
                }
            }
            Text(achievement.title)
                .font(.caption).fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                .lineLimit(2)
                .frame(height: 35, alignment: .top)
        }
        .contentShape(Rectangle())
    }
}

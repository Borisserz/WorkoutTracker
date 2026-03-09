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
                    
                    // 2. АЧИВКИ С ГРАДАЦИЕЙ УРОВНЕЙ
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("Achievements")).font(.title3).bold().padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(cachedAchievements) { achievement in
                                AchievementBadge(achievement: achievement)
                                    .onTapGesture {
                                        selectedAchievement = achievement
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    // 3. РЕКОРДЫ
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
            // Алерты
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
                weightManager.initializeFirstWeightIfNeeded(from: userBodyWeight)
                updateCache()
            }
            .onChange(of: workouts.count) { _, _ in
                updateCache()
            }
            .alert(item: $selectedAchievement) { achievement in
                // Кастомный текст алерта в зависимости от статуса ачивки
                let titleStr = NSLocalizedString(achievement.title, comment: "")
                let descStr = NSLocalizedString(achievement.description, comment: "")
                let statusMsg = achievement.isUnlocked ? "🏆 \(NSLocalizedString(achievement.tier.name.stringKey ?? "", comment: "")) Level" : "🔒 Locked"
                
                return Alert(
                    title: Text(titleStr),
                    message: Text("\(descStr)\n\n\(statusMsg)\n\(achievement.progress)"),
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

// Извлечение ключа для локализации
extension LocalizedStringKey {
    var stringKey: String? {
        Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String
    }
}

// MARK: - Медаль-Ачивка с Градацией (Матовый дизайн)
struct AchievementBadge: View {
    let achievement: Achievement
    
    // Более спокойные, "настоящие" металлические цвета для градиента
    var angularColors: [Color] {
        switch achievement.tier {
        case .none:
            return [.gray.opacity(0.3), .gray.opacity(0.2), .gray.opacity(0.3)]
        case .bronze:
            return [Color(red: 0.7, green: 0.4, blue: 0.2), Color(red: 0.9, green: 0.6, blue: 0.3), Color(red: 0.5, green: 0.25, blue: 0.1), Color(red: 0.7, green: 0.4, blue: 0.2)]
        case .silver:
            return [Color(white: 0.6), Color(white: 0.9), Color(white: 0.5), Color(white: 0.6)]
        case .gold:
            return [Color(red: 0.9, green: 0.7, blue: 0.0), Color(red: 1.0, green: 0.9, blue: 0.3), Color(red: 0.7, green: 0.5, blue: 0.0), Color(red: 0.9, green: 0.7, blue: 0.0)]
        case .diamond:
            return [.cyan, .blue, .purple, .cyan]
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Базовый темный фон круга
                Circle()
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                
                if achievement.isUnlocked {
                    // Кольцо с металлическим градиентом
                    Circle()
                        .strokeBorder(
                            AngularGradient(gradient: Gradient(colors: angularColors), center: .center),
                            lineWidth: 8
                        )
                        // Аккуратная тень под кольцом вместо вырвиглазного свечения
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                    
                    // Объемная иконка
                    Image(systemName: achievement.icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: Array(angularColors.prefix(2)),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    
                } else {
                    // Состояние "Заблокировано"
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.2), lineWidth: 8)
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    // Замок
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(Color.gray.opacity(0.8)))
                        .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
                        .offset(x: 20, y: 20)
                }
            }
            .frame(width: 80, height: 80)
            
            // Текст ачивки
            Text(LocalizedStringKey(achievement.title))
                .font(.caption)
                .fontWeight(achievement.isUnlocked ? .bold : .medium)
                .multilineTextAlignment(.center)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                .lineLimit(2)
                .frame(height: 35, alignment: .top)
        }
        .contentShape(Rectangle())
    }
}


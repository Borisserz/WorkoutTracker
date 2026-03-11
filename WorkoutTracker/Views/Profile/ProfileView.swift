internal import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var userStats: [UserStats]
    
    // Вытягиваем историю веса напрямую из БД
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightHistory: [WeightEntry]
    
    @AppStorage("userName") private var userName = "Fitness Enthusiast"
    @AppStorage("userBodyWeight") private var userBodyWeight = 75.0  // Хранится в кг
    @AppStorage("userGender") private var userGender = "male" // "male" or "female"
    
    @ObservedObject private var unitsManager = UnitsManager.shared
    
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
        let stats = userStats.first ?? UserStats()
        let currentStreak = viewModel.streakCount
        
        cachedAchievements = AchievementCalculator.calculateAchievements(
            totalWorkouts: stats.totalWorkouts,
            totalVolume: stats.totalVolume,
            totalDistance: stats.totalDistance,
            earlyWorkouts: stats.earlyWorkouts,
            nightWorkouts: stats.nightWorkouts,
            streak: currentStreak
        )
        
        let container = modelContext.container
        Task.detached(priority: .userInitiated) {
            let bgContext = ModelContext(container)
            let descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate<Workout> { $0.endTime != nil }
            )
            
            let bgWorkouts = (try? bgContext.fetch(descriptor)) ?? []
            let records = StatisticsManager.getAllPersonalRecords(workouts: bgWorkouts)
            
            await MainActor.run {
                self.cachedPersonalRecords = records
            }
        }
    }
    
    private var cacheTrigger: String {
        guard let stats = userStats.first else { return "0-0.0" }
        return "\(stats.totalWorkouts)-\(stats.totalVolume)"
    }
    
    var body: some View {
        ZStack {
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
                        
                        // 2. АЧИВКИ
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey("Achievements")).font(.title3).bold().padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(cachedAchievements) { achievement in
                                    AchievementBadge(achievement: achievement)
                                        .onTapGesture {
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                selectedAchievement = achievement
                                            }
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
                    Button(LocalizedStringKey("Save")) { 
                        let trimmedName = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedName.isEmpty { userName = trimmedName } 
                    }
                    Button(LocalizedStringKey("Cancel"), role: .cancel) { }
                }
                .alert(LocalizedStringKey("Update Body Weight"), isPresented: $isEditingWeight) {
                    TextField(LocalizedStringKey("Weight (\(unitsManager.weightUnitString()))"), text: $tempWeight).keyboardType(.decimalPad)
                    Button(LocalizedStringKey("Save")) { 
                        let sanitizedWeight = tempWeight.replacingOccurrences(of: ",", with: ".")
                        if let val = Double(sanitizedWeight) { 
                            let weightInKg = unitsManager.convertToKilograms(val)
                            userBodyWeight = weightInKg
                            
                            // Сохраняем в БД напрямую через SwiftData
                            let newEntry = WeightEntry(date: Date(), weight: weightInKg)
                            modelContext.insert(newEntry)
                        }
                    }
                    Button(LocalizedStringKey("Cancel"), role: .cancel) { }
                }
                .sheet(isPresented: $showingWeightHistory) {
                    WeightHistoryView()
                }
                .onAppear {
                    // Добавляем первую запись в SwiftData, если история пуста
                    if weightHistory.isEmpty {
                        let initialEntry = WeightEntry(date: Date(), weight: userBodyWeight)
                        modelContext.insert(initialEntry)
                    }
                    updateCache()
                }
                .onChange(of: cacheTrigger) { _, _ in
                    updateCache()
                }
            }
            
            // 4. КАСТОМНЫЙ АНИМИРОВАННЫЙ ПОПАП АЧИВКИ (С Конфетти)
            if let achievement = selectedAchievement {
                AchievementPopupView(achievement: achievement) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedAchievement = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(100)
            }
        }
    }
    
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

// MARK: - Медаль-Ачивка с Градацией (Матовый дизайн)
struct AchievementBadge: View {
    let achievement: Achievement
    
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
                Circle()
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                
                if achievement.isUnlocked {
                    Circle()
                        .strokeBorder(
                            AngularGradient(gradient: Gradient(colors: angularColors), center: .center),
                            lineWidth: 8
                        )
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                    
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
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.2), lineWidth: 8)
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.gray.opacity(0.3))
                    
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
            
            Text(achievement.title)
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

// MARK: - Анимированный попап для просмотра достижения
struct AchievementPopupView: View {
    let achievement: Achievement
    let onClose: () -> Void
    
    @State private var isAnimating = false
    
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
        ZStack {
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            
            if achievement.isUnlocked {
                AchievementConfetti()
                    .allowsHitTesting(false)
            }
            
            VStack(spacing: 24) {
                ZStack {
                    if achievement.isUnlocked {
                        Circle()
                            .fill(AngularGradient(gradient: Gradient(colors: angularColors), center: .center))
                            .frame(width: 110, height: 110)
                            .blur(radius: isAnimating ? 20 : 10)
                            .opacity(0.6)
                        
                        Circle()
                            .strokeBorder(
                                AngularGradient(gradient: Gradient(colors: angularColors), center: .center),
                                lineWidth: 10
                            )
                            .background(Circle().fill(Color(UIColor.secondarySystemBackground)))
                        
                        Image(systemName: achievement.icon)
                            .font(.system(size: 45, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: Array(angularColors.prefix(2)),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                    } else {
                        Circle()
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 10)
                            .background(Circle().fill(Color(UIColor.secondarySystemBackground)))
                        
                        Image(systemName: achievement.icon)
                            .font(.system(size: 45, weight: .bold))
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.gray.opacity(0.8)))
                            .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 3))
                            .offset(x: 35, y: 35)
                    }
                }
                .frame(width: 110, height: 110)
                .scaleEffect(isAnimating ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                
                VStack(spacing: 8) {
                    Text(achievement.title)
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                    
                    Text(achievement.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    if achievement.isUnlocked {
                        HStack(spacing: 4) {
                            Text("🏆")
                            Text(achievement.tier.name)
                            Text(LocalizedStringKey("Level"))
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                    } else {
                        HStack(spacing: 4) {
                            Text("🔒")
                            Text(LocalizedStringKey("Locked"))
                        }
                        .font(.headline)
                        .foregroundColor(.gray)
                    }
                    
                    Text(achievement.progress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(12)
                
                Button(action: onClose) {
                    Text(LocalizedStringKey("Cool!"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 30)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct AchievementConfetti: View {
    @State private var animate = false
    
    let colors: [Color] = [.blue, .yellow, .green, .pink, .purple, .orange, .cyan]
    
    var body: some View {
        ZStack {
            ForEach(0..<45, id: \.self) { i in
                let randomColor = colors.randomElement()!
                let randomSize = CGFloat.random(in: 6...14)
                let randomAngle = Angle.degrees(Double.random(in: 0...360))
                let randomDistance = CGFloat.random(in: 100...350)
                
                Rectangle()
                    .fill(randomColor)
                    .frame(width: randomSize, height: randomSize)
                    .rotationEffect(animate ? .degrees(Double.random(in: 180...720)) : .zero)
                    .offset(x: animate ? cos(randomAngle.radians) * randomDistance : 0,
                            y: animate ? sin(randomAngle.radians) * randomDistance : 0)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: Double.random(in: 0.8...1.5))
                        .delay(Double.random(in: 0...0.1)),
                        value: animate
                    )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animate = true
            }
        }
    }
}


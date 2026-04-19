internal import SwiftUI
import SwiftData
import PhotosUI
import Charts

// MARK: - Главный экран профиля
struct ProfileView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query private var userStats: [UserStats]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightHistory: [WeightEntry]
    
    @AppStorage(Constants.UserDefaultsKeys.userName.rawValue) private var userName = ""
    @AppStorage(Constants.UserDefaultsKeys.userAvatar.rawValue) private var userAvatar = ""
    @AppStorage(Constants.UserDefaultsKeys.userBodyWeight.rawValue) private var userBodyWeight = 75.0
    @AppStorage("userHeight") private var userHeight = 180
    @AppStorage("userAge") private var userAge = 25
    
    @Environment(UnitsManager.self) var unitsManager
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(ProfileViewModel.self) private var profileVM
    @Environment(UserStatsViewModel.self) private var userStatsViewModel
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    
    // Анимации при появлении
    @State private var isAppeared = false
    
    // Дебаунсер для сохранения веса, чтобы не спамить БД при быстрых кликах +/-
    @State private var weightSaveTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                ProfileBreathingBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        ProfileHeader(
                            profileImage: $profileImage,
                            selectedPhotoItem: $selectedPhotoItem,
                            userName: $userName
                        )
                        
                        LevelProgressBar(progressManager: userStatsViewModel.progressManager)
                        
                        if weightHistory.count >= 2 {
                            YearlyTransformationView(
                                startWeight: weightHistory.last?.weight ?? 0.0,
                                currentWeight: weightHistory.first?.weight ?? 0.0,
                                unitsManager: unitsManager
                            )
                        }
                        
                        if !profileVM.cachedAchievements.isEmpty {
                            AchievementsCarousel(achievements: profileVM.cachedAchievements)
                        }
                        
                        if !profileVM.cachedPersonalRecords.isEmpty {
                            PersonalRecordsView(records: profileVM.cachedPersonalRecords, unitsManager: unitsManager)
                        }
                        
                        if !weightHistory.isEmpty {
                            BodyProgressChartView(weightHistory: weightHistory, unitsManager: unitsManager)
                        }
                        
                        BodyStatsView(weight: $userBodyWeight, height: $userHeight, age: $userAge)
                            .onChange(of: userBodyWeight) { _, newValue in
                                debounceWeightSave(newWeight: newValue)
                            }
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 30)
                    .opacity(isAppeared ? 1 : 0)
                    .offset(y: isAppeared ? 0 : 20)
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadInitialData()
            withAnimation(.easeOut(duration: 0.6)) { isAppeared = true }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in handlePhotoSelection(newItem) }
    }
    
    // MARK: - Logic
    private func debounceWeightSave(newWeight: Double) {
        weightSaveTask?.cancel()
        weightSaveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // Ждем 0.8 сек после последнего нажатия
            guard !Task.isCancelled else { return }
            await userStatsViewModel.addWeightEntry(weight: newWeight)
        }
    }
    
    private func loadInitialData() {
        profileImage = ProfileImageManager.shared.loadImage()
        Task {
            await profileVM.loadProfileData(stats: userStats.first ?? UserStats(), currentStreak: dashboardViewModel.streakCount, unitsManager: unitsManager, modelContainer: context.container)
        }
        if weightHistory.isEmpty && userBodyWeight > 0.0 {
            Task { await userStatsViewModel.addWeightEntry(weight: userBodyWeight) }
        }
    }
    
    private func handlePhotoSelection(_ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                await MainActor.run {
                    profileImage = uiImage
                    ProfileImageManager.shared.saveImage(uiImage)
                }
            }
        }
    }
}

// MARK: - 1. Хедер
struct ProfileHeader: View {
    @Binding var profileImage: UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var userName: String
    
    var body: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .shadow(color: .red.opacity(0.6), radius: 20, x: 0, y: 10)
                    
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 76, height: 76)
                            .clipShape(Circle())
                    } else if UIImage(named: "fire_mascot") != nil {
                        Image("fire_mascot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .offset(y: -5)
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                    }
                }
            }
            
            VStack(spacing: 4) {
                TextField("Атлет", text: $userName)
                    .font(.title2).bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("@" + (userName.isEmpty ? "athlete" : userName.lowercased().replacingOccurrences(of: " ", with: "_")))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - 2. Полоса прогресса (Подключена к ProgressManager)
struct LevelProgressBar: View {
    let progressManager: ProgressManager
    
    var body: some View {
        let progress = CGFloat(progressManager.progressPercentage)
        
        VStack(spacing: 12) {
            HStack {
                Text("Уровень \(progressManager.level)")
                    .font(.caption).bold()
                    .foregroundColor(progress > 0 ? .orange : .gray)
                Spacer()
                Text("\(progressManager.currentXPInLevel) XP")
                    .font(.subheadline).bold()
                    .foregroundColor(.red)
                Spacer()
                Text("Уровень \(progressManager.level + 1)")
                    .font(.caption).bold()
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.05)).frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(colors: [.orange, .red, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 12)
                        .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 0)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

// MARK: - 3. Трансформация
struct YearlyTransformationView: View {
    let startWeight: Double
    let currentWeight: Double
    let unitsManager: UnitsManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Начальный вес").font(.caption).foregroundColor(.gray)
                let sWeight = unitsManager.convertFromKilograms(startWeight)
                Text("\(LocalizationHelper.shared.formatDecimal(sWeight)) \(unitsManager.weightUnitString())")
                    .font(.headline).foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            
            let diff = currentWeight - startWeight
            let icon = diff > 0 ? "arrow.up.right" : (diff < 0 ? "arrow.down.right" : "arrow.right")
            let color: Color = diff > 0 ? .orange : (diff < 0 ? .green : .gray)
            
            Image(systemName: icon).foregroundColor(color).font(.system(size: 20, weight: .bold))
            Spacer()
            VStack(alignment: .trailing) {
                Text("Сейчас").font(.caption).foregroundColor(.gray)
                let cWeight = unitsManager.convertFromKilograms(currentWeight)
                Text("\(LocalizationHelper.shared.formatDecimal(cWeight)) \(unitsManager.weightUnitString())")
                    .font(.headline).foregroundColor(color)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

// MARK: - 4. 3D Карусель (Интегрирована с БД ачивок)
struct AchievementsCarousel: View {
    let achievements: [Achievement]
    
    @State private var currentIndex: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        let total = CGFloat(achievements.count)
        let current = currentIndex - (dragOffset / 250)
        
        VStack(alignment: .leading, spacing: 16) {
            Text("Ваши трофеи (Свайп)")
                .font(.title3).bold()
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            ZStack {
                ForEach(0..<achievements.count, id: \.self) { i in
                    let distance = shortestDistance(from: current, to: CGFloat(i), total: total)
                    let angle = distance * (360.0 / total)
                    let angleRad = angle * .pi / 180
                    
                    let x = sin(angleRad) * 280
                    let z = cos(angleRad)
                    
                    let scale = 0.75 + 0.25 * z
                    let opacity = max(0, 0.1 + 0.9 * z)
                    
                    AchievementDesignerCard(
                        achievement: achievements[i]
                    )
                    .offset(x: x)
                    .scaleEffect(scale)
                    .opacity(z > -0.3 ? opacity : 0)
                    .zIndex(z)
                    .rotation3DEffect(.degrees(angle * 0.7), axis: (x: 0, y: 1, z: 0))
                }
            }
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($dragOffset) { val, state, _ in
                        state = val.translation.width
                    }
                    .onEnded { val in
                        let moved = val.translation.width / 250
                        let target = round(currentIndex - moved)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentIndex = target
                        }
                    }
            )
        }
    }
    
    func shortestDistance(from current: CGFloat, to target: CGFloat, total: CGFloat) -> CGFloat {
        let diff = target - current
        var wrapped = diff.truncatingRemainder(dividingBy: total)
        if wrapped < 0 { wrapped += total }
        if wrapped > total / 2.0 { wrapped -= total }
        return wrapped
    }
}

struct AchievementDesignerCard: View {
    let achievement: Achievement
    
    @State private var isBreathing = false
    @State private var showCloud = false
    
    // ВЕРНУЛИ КРАСОЧНЫЕ НЕОНОВЫЕ ЦВЕТА ДИЗАЙНЕРА ДЛЯ УРОВНЕЙ
    private var glowColor: Color {
        guard achievement.isUnlocked else { return Color.white.opacity(0.1) }
        switch achievement.tier {
        case .none: return .clear
        case .bronze: return .orange  // Яркий оранжевый вместо скучного коричневого
        case .silver: return .cyan    // Кибер-синий вместо серого
        case .gold: return .yellow    // Яркий желтый
        case .diamond: return .purple // Неоновый фиолетовый
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                    .font(.system(size: 40))
                    // ГРАДИЕНТ ДИЗАЙНЕРА
                    .foregroundStyle(LinearGradient(colors: [.white, glowColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                VStack(spacing: 4) {
                    Text(achievement.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    
                    if achievement.isUnlocked {
                        Text(achievement.tier.name)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    } else {
                        Text(achievement.progress)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 130, height: 160)
            .background(.ultraThinMaterial)
            // ПОДСВЕТКА ФОНА ДИЗАЙНЕРА
            .background(glowColor.opacity(achievement.isUnlocked ? 0.15 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
            // ТЕНИ ДИЗАЙНЕРА
            .shadow(color: glowColor.opacity(isBreathing && achievement.isUnlocked ? 0.6 : 0.1), radius: isBreathing ? 20 : 5)
            .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 50, perform: {}, onPressingChanged: { isPressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showCloud = isPressing
                    if isPressing { HapticManager.shared.impact(.soft) }
                }
            })
            .onAppear {
                if achievement.isUnlocked {
                    withAnimation(.easeInOut(duration: .random(in: 1.5...2.5)).repeatForever(autoreverses: true)) {
                        isBreathing = true
                    }
                }
            }
            
            // ТУЛТИП ДИЗАЙНЕРА
            if showCloud {
                VStack(spacing: 0) {
                    Text(achievement.description)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .white.opacity(0.4), radius: 10, y: 5)
                    
                    BubbleTail()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 14, height: 8)
                }
                .offset(y: -175)
                .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
    }
}
struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 5. Личные Рекорды (Интегрировано с БД)
struct PersonalRecordsView: View {
    let records: [BestResult]
    let unitsManager: UnitsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Личные рекорды")
                .font(.title3).bold()
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ForEach(records.prefix(5)) { record in
                    RecordRow(
                        title: LocalizationHelper.shared.translateName(record.exerciseName),
                        value: record.value,
                        period: record.date.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            }
            .padding()
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal, 20)
    }
}

struct RecordRow: View {
    var title: String
    var value: String
    var period: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.headline).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
                Text(period).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 6. График прогресса (Интегрирован с БД)
struct BodyProgressChartView: View {
    let weightHistory: [WeightEntry]
    let unitsManager: UnitsManager
    @State private var mascotBreathe = false
    
    var chartData: [WeightEntry] {
        // Берем последние 10 записей и разворачиваем для хронологического порядка слева направо
        Array(weightHistory.prefix(10)).reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Динамика веса").font(.title3).bold().foregroundColor(.white)
                Spacer()
                if let first = weightHistory.last?.weight, let last = weightHistory.first?.weight {
                    let diff = last - first
                    if abs(diff) > 0.1 {
                        let diffConverted = unitsManager.convertFromKilograms(diff)
                        let sign = diff > 0 ? "+" : ""
                        let color: Color = diff < 0 ? .green : .orange
                        Text("\(sign)\(LocalizationHelper.shared.formatDecimal(diffConverted)) \(unitsManager.weightUnitString())")
                            .font(.caption).bold()
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(color.opacity(0.2)).foregroundColor(color).clipShape(Capsule())
                    }
                }
            }
            
            Chart {
                ForEach(Array(chartData.enumerated()), id: \.element.id) { index, item in
                    let w = unitsManager.convertFromKilograms(item.weight)
                    LineMark(x: .value("Date", item.date), y: .value("Weight", w))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    AreaMark(x: .value("Date", item.date), y: .value("Weight", w))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [.red.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                    
                    if index == chartData.count - 1 {
                        PointMark(x: .value("Date", item.date), y: .value("Weight", w))
                            .foregroundStyle(.clear)
                            .annotation(position: .top, alignment: .center) {
                                if UIImage(named: "fire_mascot") != nil {
                                    Image("fire_mascot")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 45, height: 45)
                                        .shadow(color: .orange, radius: mascotBreathe ? 10 : 2)
                                        .scaleEffect(mascotBreathe ? 1.15 : 0.95)
                                        .offset(y: -15)
                                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: mascotBreathe)
                                        .onAppear { mascotBreathe = true }
                                } else {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                        .font(.title2)
                                        .offset(y: -10)
                                }
                            }
                    }
                }
            }
            .frame(height: 140)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

// MARK: - 7. Антропометрия
struct BodyStatsView: View {
    @Binding var weight: Double
    @Binding var height: Int
    @Binding var age: Int
    
    var body: some View {
        HStack(spacing: 12) {
            StatAdjuster(title: "Вес", value: String(format: "%.1f", weight), unit: "кг", onMinus: { weight -= 0.5 }, onPlus: { weight += 0.5 })
            StatAdjuster(title: "Рост", value: "\(height)", unit: "см", onMinus: { height -= 1 }, onPlus: { height += 1 })
            StatAdjuster(title: "Возраст", value: "\(age)", unit: "лет", onMinus: { age -= 1 }, onPlus: { age += 1 })
        }
        .padding(.horizontal, 20)
    }
}

struct StatAdjuster: View {
    var title: String; var value: String; var unit: String
    var onMinus: () -> Void; var onPlus: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.caption).foregroundColor(.gray)
            HStack(spacing: 0) {
                Text(value).font(.system(size: 20, weight: .bold)).monospacedDigit()
                Text(unit).font(.caption).foregroundColor(.gray).padding(.leading, 2)
            }
            .foregroundColor(.white)
            HStack(spacing: 16) {
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); withAnimation { onMinus() } }) { Image(systemName: "minus.circle.fill").foregroundColor(.white.opacity(0.3)) }
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); withAnimation { onPlus() } }) { Image(systemName: "plus.circle.fill").foregroundColor(.white.opacity(0.3)) }
            }
            .font(.title3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - Фон
struct ProfileBreathingBackground: View {
    @State private var phase = false
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).edgesIgnoringSafeArea(.all)
            Circle().fill(Color.red.opacity(0.08)).frame(width: 350, height: 350).blur(radius: 120)
                .offset(x: phase ? 40 : -40, y: phase ? -30 : 30)
                .scaleEffect(phase ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: phase)
                .onAppear { phase = true }
        }
    }
}

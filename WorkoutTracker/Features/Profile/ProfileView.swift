// ============================================================
// FILE: WorkoutTracker/Features/Profile/ProfileView.swift
// ============================================================

internal import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query private var userStats: [UserStats]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightHistory: [WeightEntry]
    
    @AppStorage(Constants.UserDefaultsKeys.userName.rawValue) private var userName = ""
    @AppStorage(Constants.UserDefaultsKeys.userAvatar.rawValue) private var userAvatar = ""
    @AppStorage(Constants.UserDefaultsKeys.userBodyWeight.rawValue) private var userBodyWeight = 0.0
    
    @Environment(UnitsManager.self) var unitsManager
    @Environment(DashboardViewModel.self) var dashboardViewModel
    
    @Environment(ProfileViewModel.self) private var profileVM
    @Environment(UserStatsViewModel.self) private var userStatsViewModel
    
    @State private var selectedAchievement: Achievement?
    @State private var showingWeightHistory = false
    @State private var showingMeasurements = false
    @State private var showEditWeight = false
    @State private var newWeightString = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    
    // Анимации при появлении
    @State private var isAppeared = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            NavigationStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        ProfileHeaderView(
                            profileImage: $profileImage,
                            selectedPhotoItem: $selectedPhotoItem,
                            userName: $userName,
                            userBodyWeight: userBodyWeight,
                            progressManager: userStatsViewModel.progressManager,
                            unitsManager: unitsManager,
                            onEditWeight: {
                                newWeightString = LocalizationHelper.shared.formatDecimal(unitsManager.convertFromKilograms(userBodyWeight == 0.0 ? 75.0 : userBodyWeight))
                                showEditWeight = true
                            },
                            onWeightTracking: { showingWeightHistory = true },
                            onMeasurements: { showingMeasurements = true }
                        )
                        .padding(.top, 10)
                        
                        ProfileStatsRow(
                            stats: userStats.first ?? UserStats(),
                            streak: dashboardViewModel.streakCount,
                            unitsManager: unitsManager
                        )
                        
                        if let forecast = profileVM.topForecast {
                            ProfileForecastBanner(forecast: forecast, unitsManager: unitsManager)
                        }
                        
                        ProfileAchievementsSection(
                            achievements: profileVM.cachedAchievements,
                            onTap: { achievement in
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedAchievement = achievement
                                }
                            }
                        )
                        
                        ProfileRecordsSection(records: profileVM.cachedPersonalRecords)
                    }
                    .padding(.bottom, 60)
                    .opacity(isAppeared ? 1 : 0)
                    .offset(y: isAppeared ? 0 : 20)
                }
                .navigationTitle(LocalizedStringKey("Profile"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(LocalizedStringKey("Close")) { dismiss() }
                            .fontWeight(.bold)
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            
            // Achievement Popup Overlay
            if let achievement = selectedAchievement {
                AchievementPopupView(achievement: achievement) {
                    withAnimation { selectedAchievement = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(100)
            }
        }
        .sheet(isPresented: $showingWeightHistory) { WeightHistoryView() }
        .sheet(isPresented: $showingMeasurements) { BodyMeasurementsView() }
        .alert(LocalizedStringKey("Update Body Weight"), isPresented: $showEditWeight) {
            TextField("Weight", text: $newWeightString).keyboardType(.decimalPad)
            Button("Save") { saveNewWeight() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your current weight in \(unitsManager.weightUnitString())")
        }
        .onAppear {
            loadInitialData()
            withAnimation(.easeOut(duration: 0.6)) { isAppeared = true }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in handlePhotoSelection(newItem) }
    }
    
    // MARK: - Logic
    
    private func saveNewWeight() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: newWeightString)?.doubleValue ?? Double(newWeightString.replacingOccurrences(of: ",", with: ".")) {
            let weightKg = unitsManager.convertToKilograms(number)
            userBodyWeight = weightKg
            Task { await userStatsViewModel.addWeightEntry(weight: weightKg) }
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

struct ProfileHeaderView: View {
    @Binding var profileImage: UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var userName: String
    
    let userBodyWeight: Double
    let progressManager: ProgressManager
    let unitsManager: UnitsManager
    
    let onEditWeight: () -> Void
    let onWeightTracking: () -> Void
    let onMeasurements: () -> Void
    
    @AppStorage(Constants.UserDefaultsKeys.userAvatar.rawValue) private var userAvatar = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Аватар без лишних кругов
            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                Group {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Text(userAvatar.isEmpty ? "🦍" : userAvatar)
                            .font(.system(size: 60))
                            .background(Color(UIColor.secondarySystemBackground))
                    }
                }
                .frame(width: 114, height: 114)
                .clipShape(Circle())
            }
            
            // Имя пользователя
            TextField("Champion", text: $userName)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            
            // Слой кнопок (Measures / Weight)
            HStack(spacing: 0) {
                Button(action: onWeightTracking) {
                    VStack(spacing: 4) {
                        Image(systemName: "scalemass.fill").font(.title3)
                        Text(LocalizedStringKey("Weight")).font(.caption2.bold()).textCase(.uppercase)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                }
                
                Divider().frame(height: 30).background(Color.gray.opacity(0.3))
                
                Button(action: onEditWeight) {
                    let displayWeight = userBodyWeight == 0.0 ? 75.0 : userBodyWeight
                    let convertedWeight = unitsManager.convertFromKilograms(displayWeight)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(LocalizationHelper.shared.formatFlexible(convertedWeight))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.blue)
                        Text(unitsManager.weightUnitString())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Divider().frame(height: 30).background(Color.gray.opacity(0.3))
                
                Button(action: onMeasurements) {
                    VStack(spacing: 4) {
                        Image(systemName: "ruler.fill").font(.title3)
                        Text(LocalizedStringKey("Measures")).font(.caption2.bold()).textCase(.uppercase)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Stats Grid (Блоки одинакового размера)

struct ProfileStatsRow: View {
    let stats: UserStats
    let streak: Int
    let unitsManager: UnitsManager
    
    // ВЫНОСИМ ЛОГИКУ В ОТДЕЛЬНОЕ СВОЙСТВО, чтобы не путать компилятор
    private var volumeInfo: (value: String, unit: String) {
        let rawKg = stats.totalVolume
        if rawKg >= 1000 {
            let tons = rawKg / 1000.0
            return (LocalizationHelper.shared.formatFlexible(tons), String(localized: "tons"))
        } else {
            let converted = unitsManager.convertFromKilograms(rawKg)
            return (LocalizationHelper.shared.formatSmart(converted), unitsManager.weightUnitString())
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ProfileStatCard(title: "Workouts", value: "\(stats.totalWorkouts)", icon: "figure.run.circle.fill", color: .cyan)
            
            ProfileStatCard(title: "Volume", value: volumeInfo.value, unit: volumeInfo.unit, icon: "dumbbell.fill", color: .purple)
            
            ProfileStatCard(title: "Streak", value: "\(streak)", unit: String(localized: "Days"), icon: "flame.fill", color: .orange)
        }
        .padding(.horizontal, 20)
    }
}

struct ProfileStatCard: View {
    let title: LocalizedStringKey
    let value: String
    var unit: String? = nil
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    
                    if let u = unit {
                        Text(u)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                }
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading) // Фиксирует одинаковую ширину колонок
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
// MARK: - Forecast Banner

struct ProfileForecastBanner: View {
    let forecast: ProgressForecast
    let unitsManager: UnitsManager
    
    var body: some View {
        let convertedWeight = unitsManager.convertFromKilograms(forecast.predictedMax)
        let weightStr = LocalizationHelper.shared.formatFlexible(convertedWeight)
        
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 48, height: 48)
                Image(systemName: "sparkles").font(.title2).foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("AI Forecast"))
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                
                Text(String(localized: "In \(forecast.timeframe) your \(forecast.exerciseName) is predicted to reach \(weightStr) \(unitsManager.weightUnitString())!"))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color(hex: "4A00E0"), Color(hex: "8E2DE2")], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(20)
        .shadow(color: Color(hex: "8E2DE2").opacity(0.4), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
}

// MARK: - Gamified Achievements Section

struct ProfileAchievementsSection: View {
    let achievements: [Achievement]
    let onTap: (Achievement) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Achievements"))
                .font(.title2)
                .bold()
                .padding(.horizontal, 24)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 20) {
                ForEach(achievements) { achievement in
                    PremiumAchievementBadge(achievement: achievement)
                        .onTapGesture { onTap(achievement) }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct PremiumAchievementBadge: View {
    let achievement: Achievement
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Background Shape
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(achievement.isUnlocked ? AnyShapeStyle(gradientForTier(achievement.tier)) : AnyShapeStyle(Color(UIColor.secondarySystemBackground)))
                    .aspectRatio(1, contentMode: .fit)
                
                // Inner Glass or Border
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(achievement.isUnlocked ? 0.3 : 0.05), lineWidth: 1)
                
                if achievement.isUnlocked {
                    Image(systemName: achievement.icon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                        .symbolEffect(.bounce, value: animateIcon)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .shadow(color: achievement.isUnlocked ? colorForTier(achievement.tier).opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
            
            VStack(spacing: 2) {
                Text(achievement.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if !achievement.isUnlocked && !achievement.progress.isEmpty {
                    Text(achievement.progress)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            if achievement.isUnlocked {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.5)) {
                    animateIcon.toggle()
                }
            }
        }
    }
    
    private func colorForTier(_ tier: AchievementTier) -> Color {
        switch tier {
        case .none: return .clear
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .diamond: return .cyan
        }
    }
    
    private func gradientForTier(_ tier: AchievementTier) -> LinearGradient {
        switch tier {
        case .bronze: return LinearGradient(colors: [.orange, .brown], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .silver: return LinearGradient(colors: [Color(white: 0.8), Color(white: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gold: return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .diamond: return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Records Section

struct ProfileRecordsSection: View {
    let records: [BestResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Personal Records"))
                .font(.title2)
                .bold()
                .padding(.horizontal, 24)
            
            if records.isEmpty {
                EmptyStateView(
                    icon: "trophy",
                    title: LocalizedStringKey("No Records Yet"),
                    message: LocalizedStringKey("Complete workouts to see your records!")
                )
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(records) { record in
                        PremiumRecordCard(record: record)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct PremiumRecordCard: View {
    let record: BestResult
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(getColor(record.type).opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: getIcon(record.type))
                    .font(.title3)
                    .foregroundColor(getColor(record.type))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(record.exerciseName))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(record.value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
    
    private func getIcon(_ type: ExerciseType) -> String {
        type == .strength ? "dumbbell.fill" : (type == .cardio ? "figure.run" : "stopwatch.fill")
    }
    
    private func getColor(_ type: ExerciseType) -> Color {
        type == .strength ? .blue : (type == .cardio ? .orange : .purple)
    }
}

// MARK: - Legacy Popup Keep (Unmodified logic, styled)

struct AchievementPopupView: View {
    let achievement: Achievement
    let onClose: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    if achievement.isUnlocked {
                        Circle()
                            .fill(tierColor(achievement.tier).opacity(0.2))
                            .frame(width: 160, height: 160)
                            .scaleEffect(isAnimating ? 1.2 : 0.9)
                            .opacity(isAnimating ? 0 : 1)
                            .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                    }
                    
                    Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                        .font(.system(size: 80))
                        .foregroundColor(achievement.isUnlocked ? tierColor(achievement.tier) : .gray)
                        .shadow(color: achievement.isUnlocked ? tierColor(achievement.tier).opacity(0.8) : .clear, radius: 20, x: 0, y: 0)
                }
                .padding(.bottom, 10)
                
                if achievement.isUnlocked {
                    Text("🏆").font(.largeTitle)
                    Text(LocalizedStringKey("Achievement Unlocked!"))
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .textCase(.uppercase)
                        .tracking(2)
                } else {
                    Text(LocalizedStringKey("Locked"))
                        .font(.headline)
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                        .tracking(2)
                }
                
                Text(achievement.title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                if achievement.isUnlocked {
                    HStack(spacing: 6) {
                        Text(LocalizedStringKey("Level:"))
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                        Text(achievement.tier.name)
                            .font(.headline)
                            .foregroundColor(tierColor(achievement.tier))
                    }
                    .padding(.top, 10)
                } else if !achievement.progress.isEmpty {
                    Text(achievement.progress)
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.top, 10)
                }
                
                Button(action: onClose) {
                    Text(LocalizedStringKey("Close"))
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(width: 200)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                }
                .padding(.top, 20)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .cornerRadius(32)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(achievement.isUnlocked ? tierColor(achievement.tier).opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 20)
        }
        .onAppear {
            if achievement.isUnlocked {
                isAnimating = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
    
    private func tierColor(_ tier: AchievementTier) -> Color {
        switch tier {
        case .none: return .clear
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .diamond: return .cyan
        }
    }
}

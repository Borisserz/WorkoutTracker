internal import SwiftUI
import SwiftData
import PhotosUI
import Charts

struct ProfileView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme 
    @Environment(ThemeManager.self) private var themeManager

    @Query private var userStats: [UserStats]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightHistory: [WeightEntry]

    @AppStorage(Constants.UserDefaultsKeys.userName.rawValue) private var userName = ""
    @AppStorage(Constants.UserDefaultsKeys.userAvatar.rawValue) private var userAvatar = ""
    @AppStorage("userHeight") private var userHeight = 180
    @AppStorage("userAge") private var userAge = 25
    @AppStorage("userBodyWeight") private var userBodyWeight: Double = 75.0

    @Environment(UnitsManager.self) var unitsManager
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(ProfileViewModel.self) private var profileVM
    @Environment(UserStatsViewModel.self) private var userStatsViewModel

    @AppStorage("show_foodtracker_promo_enabled", store: UserDefaults(suiteName: "group.com.borisdev.WorkoutTracker")) private var showFoodTrackerPromo = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?

    @State private var isAppeared = false
    @State private var showEditMetrics = false
    @State private var showAchievementsFolder = false

    var body: some View {
        NavigationStack {
            ZStack {
                ProfileBreathingBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        ProfileHeader(
                            profileImage: $profileImage,
                            selectedPhotoItem: $selectedPhotoItem,
                            userName: $userName,
                            title: userStatsViewModel.progressManager.currentTitle
                        )

                        LevelProgressBar(progressManager: userStatsViewModel.progressManager)

                        if weightHistory.count >= 2 {
                            YearlyTransformationView(
                                startWeight: weightHistory.last?.weight ?? 0.0,
                                currentWeight: weightHistory.first?.weight ?? 0.0,
                                unitsManager: unitsManager
                            )
                        }

                        trackingNavigationSection
                        
                        if !profileVM.cachedAchievements.isEmpty {
                            AchievementsFolderButton(
                                achievements: profileVM.cachedAchievements,
                                onOpenFolder: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    showAchievementsFolder = true
                                }
                            )
                        }

                        if !profileVM.cachedPersonalRecords.isEmpty {
                            PersonalRecordsView(records: profileVM.cachedPersonalRecords, unitsManager: unitsManager)
                        }

                        if !weightHistory.isEmpty {
                            BodyProgressChartView(weightHistory: weightHistory, unitsManager: unitsManager)
                        }

                        UserMetricsOverviewCard(height: userHeight, age: userAge, weight: userBodyWeight) { showEditMetrics = true }

                        if showFoodTrackerPromo {
                            crossPromoBanner
                                .padding(.horizontal, 20)
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
                    Button("Close") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            loadInitialData()
            withAnimation(.easeOut(duration: 0.6)) { isAppeared = true }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in handlePhotoSelection(newItem) }
        .sheet(isPresented: $showEditMetrics) {
            EditMetricsSheet()
                .presentationDetents([.height(450)])
                .presentationCornerRadius(35)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAchievementsFolder) {
            AchievementsFolderSheet(achievements: profileVM.cachedAchievements)
                .presentationDetents([.fraction(0.88), .large])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
    }

    private var trackingNavigationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Body Metrics")
                .font(.title3).bold()
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ProfileMenuCard(
                    title: "Weight & Progress Photos",
                    subtitle: "Weight history and before/after comparison",
                    icon: "camera.macro",
                    color: .orange,
                    destination: WeightHistoryView()
                )

                ProfileMenuCard(
                    title: "Body Measurements",
                    subtitle: "Muscle volumes and fat percentage",
                    icon: "ruler.fill",
                    color: themeManager.current.primaryAccent,
                    destination: BodyMeasurementsView()
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private func loadInitialData() {
        profileImage = ProfileImageManager.shared.loadImage()
        Task {
            await profileVM.loadProfileData(stats: userStats.first ?? UserStats(), currentStreak: dashboardViewModel.streakCount, unitsManager: unitsManager, modelContainer: context.container)
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

    private var crossPromoBanner: some View {
        Button(action: {
            if let url = URL(string: "foodtracker://"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else if let storeUrl = URL(string: "https://apps.apple.com/app/id6778506345") {
                UIApplication.shared.open(storeUrl, options: [:], completionHandler: nil)
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.pink.opacity(0.4), radius: 8, y: 4)
                    
                    Image(systemName: "fork.knife")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Food Tracker")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                    
                    Text("Smart nutrition & AI coach")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 0)
                
                VStack {
                    Text("GET")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.pink.opacity(0.15))
                        .clipShape(Capsule())
                    
                    Text("In-App Purchases")
                        .font(.system(size: 8))
                        .foregroundStyle(.gray)
                        .padding(.top, 2)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(colorScheme == .dark ? AnyShapeStyle(Color.white.opacity(0.05)) : AnyShapeStyle(Color.white))
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.pink.opacity(0.5), Color.orange.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ProfileMenuCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: Destination

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.title3.bold())
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title))
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Text(LocalizedStringKey(subtitle))
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .gray)
                        .lineLimit(3).minimumScaleFactor(0.8).allowsTightening(true)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.3))
            }
            .padding(16)
            .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct ProfileHeader: View {
    @Binding var profileImage: UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var userName: String
    var title: String
    @Environment(\.colorScheme) private var colorScheme 

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
                    
                    // Edit Badge
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(colorScheme == .dark ? Color.black : Color.white, lineWidth: 2)
                            )
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 28, y: 28)
                }
            }

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    TextField("Athlete", text: $userName)
                        .font(.title2).bold()
                        .foregroundColor(colorScheme == .dark ? .white : .black) 
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 160)
                    
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text("@" + (userName.isEmpty ? "athlete" : userName.lowercased().replacingOccurrences(of: " ", with: "_")))
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray) 
            }
        }
    }
}

struct LevelProgressBar: View {
    let progressManager: ProgressManager

    var body: some View {
        let progress = CGFloat(progressManager.progressPercentage)

        VStack(spacing: 10) {
            // Top row: Level Badge + Title + XP numbers
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelAmber)

                        Text("Уровень \(progressManager.level)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.pastelAmber)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))

                    Text(progressManager.currentTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("\(progressManager.currentXPInLevel)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(PastelTheme.pastelOat)

                    Text("XP")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(PastelTheme.textTertiary)
                }
            }

            // Recessed High-Contrast Athletic Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(height: 10)

                    Capsule()
                        .fill(PastelTheme.pastelAmber)
                        .frame(width: max(10, geo.size.width * progress), height: 10)
                }
            }
            .frame(height: 10)

            // Bottom Progress status
            HStack {
                Text("\(Int(progress * 100))% до уровня \(progressManager.level + 1)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)

                Spacer()

                Text("Цель: \(progressManager.xpToNextLevel) XP")
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(PastelTheme.textTertiary)
            }
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

struct YearlyTransformationView: View {
    let startWeight: Double
    let currentWeight: Double
    let unitsManager: UnitsManager
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Start weight").font(.caption).foregroundColor(.gray)
                let sWeight = unitsManager.convertFromKilograms(startWeight)
                Text("\(LocalizationHelper.shared.formatDecimal(sWeight)) \(unitsManager.weightUnitString())")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7)) 
            }
            Spacer()

            let diff = currentWeight - startWeight
            let icon = diff > 0 ? "arrow.up.right" : (diff < 0 ? "arrow.down.right" : "arrow.right")
            let color: Color = diff > 0 ? .orange : (diff < 0 ? .green : .gray)

            Image(systemName: icon).foregroundColor(color).font(.system(size: 20, weight: .bold))
            Spacer()
            VStack(alignment: .trailing) {
                Text("Now").font(.caption).foregroundColor(.gray)
                let cWeight = unitsManager.convertFromKilograms(currentWeight)
                Text("\(LocalizationHelper.shared.formatDecimal(cWeight)) \(unitsManager.weightUnitString())")
                    .font(.headline).foregroundColor(color)
            }
        }
        .padding()
        .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white)) 
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1)) 
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2) 
        .padding(.horizontal, 20)
    }
}

/// Tactile folder / dossier button representing the achievements archive
struct AchievementsFolderButton: View {
    let achievements: [Achievement]
    let onOpenFolder: () -> Void

    private var unlockedCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }

    var body: some View {
        Button(action: onOpenFolder) {
            HStack(spacing: 14) {
                // Folder tab emblem with layered stacked papers aesthetic
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 46, height: 46)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PastelTheme.cardBorder, lineWidth: 1)
                        )
                        .rotationEffect(.degrees(-4))

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PastelTheme.cardSurface)
                        .frame(width: 46, height: 46)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PastelTheme.cardBorderFocused, lineWidth: 1)
                        )

                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(PastelTheme.pastelAmber)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Папка наград и достижений")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text("\(unlockedCount) из \(achievements.count) получено")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(PastelTheme.pastelSage)

                        Rectangle()
                            .fill(PastelTheme.cardBorder)
                            .frame(width: 1, height: 10)

                        Text("Подробнее")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(PastelTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PastelTheme.textSecondary)
            }
            .padding(14)
            .background(PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}

/// Luxury modal sheet presenting the achievements showcase in elegant tiles.
/// Supports tapping or long-pressing any achievement to inspect details and meaning.
struct AchievementsFolderSheet: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss

    @State private var inspectedAchievement: Achievement? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header description
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Коллекция наград")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundStyle(PastelTheme.textPrimary)

                                Text("Зажмите любую плитку для проверки условий")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(PastelTheme.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        // 2-Column Luxury Achievement Tiles Grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(achievements) { achievement in
                                AchievementTileCard(
                                    achievement: achievement,
                                    isSelected: inspectedAchievement?.id == achievement.id,
                                    onTap: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            if inspectedAchievement?.id == achievement.id {
                                                inspectedAchievement = nil
                                            } else {
                                                inspectedAchievement = achievement
                                            }
                                        }
                                    },
                                    onLongPress: {
                                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            inspectedAchievement = achievement
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 40)
                    }
                }

                // Inspection HUD Overlay at the bottom if an achievement is selected
                if let inspected = inspectedAchievement {
                    VStack {
                        Spacer()

                        AchievementInspectionCard(
                            achievement: inspected,
                            onClose: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    inspectedAchievement = nil
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Архив наград")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.pastelOat)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct AchievementTileCard: View {
    let achievement: Achievement
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    private var tierColor: Color {
        guard achievement.isUnlocked else { return PastelTheme.cardBorder }
        switch achievement.tier {
        case .none: return PastelTheme.cardBorder
        case .bronze: return PastelTheme.pastelPeach
        case .silver: return PastelTheme.pastelOat
        case .gold: return PastelTheme.pastelAmber
        case .diamond: return PastelTheme.pastelLavender
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack {
                    Text(achievement.tier.name)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(tierColor)

                    Spacer()

                    if achievement.isUnlocked {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelSage)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PastelTheme.textTertiary)
                    }
                }

                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ? tierColor.opacity(0.15) : PastelTheme.cardSurfaceSubtle)
                        .frame(width: 44, height: 44)

                    Image(systemName: achievement.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(achievement.isUnlocked ? tierColor : PastelTheme.textTertiary)
                }
                .padding(.vertical, 4)

                Text(achievement.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(achievement.isUnlocked ? PastelTheme.textPrimary : PastelTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 34)

                Text(achievement.progress.isEmpty ? (achievement.isUnlocked ? "Получено" : "В процессе") : achievement.progress)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(PastelTheme.textTertiary)
                    .lineLimit(1)
            }
            .padding(12)
            .background(isSelected ? PastelTheme.cardSurfaceSubtle : PastelTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? tierColor : (achievement.isUnlocked ? tierColor.opacity(0.3) : PastelTheme.cardBorder), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in onLongPress() }
        )
    }
}

private struct AchievementInspectionCard: View {
    let achievement: Achievement
    let onClose: () -> Void

    private var tierColor: Color {
        guard achievement.isUnlocked else { return PastelTheme.cardBorder }
        switch achievement.tier {
        case .none: return PastelTheme.cardBorder
        case .bronze: return PastelTheme.pastelPeach
        case .silver: return PastelTheme.pastelOat
        case .gold: return PastelTheme.pastelAmber
        case .diamond: return PastelTheme.pastelLavender
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tierColor.opacity(0.18))
                        .frame(width: 46, height: 46)

                    Image(systemName: achievement.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(tierColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(achievement.tier.name)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(tierColor)

                        Text("·")
                            .foregroundStyle(PastelTheme.textTertiary)

                        Text(achievement.isUnlocked ? "Награда получена" : "Условие не выполнено")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(achievement.isUnlocked ? PastelTheme.pastelSage : PastelTheme.textSecondary)
                    }

                    Text(achievement.title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PastelTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Text(achievement.description)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PastelTheme.textSecondary)
                .lineSpacing(3)

            if !achievement.progress.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(PastelTheme.pastelAmber)

                    Text("Текущий прогресс: \(achievement.progress)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.pastelAmber)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(PastelTheme.cardSurfaceSubtle)
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tierColor.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 24, y: 8)
    }
}

struct AchievementDesignerCard: View {
    let achievement: Achievement
    @Environment(\.colorScheme) private var colorScheme 

    @State private var isBreathing = false
    @State private var showCloud = false

    private var glowColor: Color {
        guard achievement.isUnlocked else { return colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.4) }
        switch achievement.tier {
        case .none: return .clear
        case .bronze: return .orange
        case .silver: return .cyan
        case .gold: return .yellow
        case .diamond: return .purple
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(achievement.isUnlocked
                                     ? AnyShapeStyle(LinearGradient(colors: [.white, glowColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                                     : AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.3) : Color.gray))

                VStack(spacing: 4) {
                    Text(achievement.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : (achievement.isUnlocked ? .black : .gray)) 
                        .multilineTextAlignment(.center)
                        .lineLimit(3).minimumScaleFactor(0.8).allowsTightening(true)
                        .minimumScaleFactor(0.7)

                    if achievement.isUnlocked {
                        Text(achievement.tier.name)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2).minimumScaleFactor(0.8).allowsTightening(true)
                    } else {
                        Text(achievement.progress)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2).minimumScaleFactor(0.8).allowsTightening(true)
                    }
                }
            }
            .frame(width: 130, height: 160)
            .background(colorScheme == .dark ? Color.black.opacity(0.6) : Color(UIColor.secondarySystemGroupedBackground))
            .background(glowColor.opacity(achievement.isUnlocked ? 0.15 : 0.0))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 1))
            .shadow(color: glowColor.opacity(isBreathing && achievement.isUnlocked ? 0.6 : (colorScheme == .dark ? 0.1 : 0.05)), radius: isBreathing ? 20 : 5)
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

            if showCloud {
                VStack(spacing: 0) {
                    Text(achievement.description)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .black.opacity(0.8) : .white) 
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.8)) 
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    BubbleTail()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.8)) 
                        .frame(width: 14, height: 8)
                }
                .offset(y: -175)
                .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
    }
}

struct PersonalRecordsView: View {
    let records: [BestResult]
    let unitsManager: UnitsManager
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Bests")
                .font(.title3).bold()
                .foregroundColor(colorScheme == .dark ? .white : .black) 

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
            .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white) 
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1)) 
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2) 
        }
        .padding(.horizontal, 20)
    }
}

struct RecordRow: View {
    var title: String
    var value: String
    var period: String
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.headline).foregroundColor(colorScheme == .dark ? .white : .black).lineLimit(1).minimumScaleFactor(0.8) 
                Text(period).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                .lineLimit(2).minimumScaleFactor(0.8).allowsTightening(true)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 8)
    }
}

struct BodyProgressChartView: View {
    let weightHistory: [WeightEntry]
    let unitsManager: UnitsManager
    @State private var mascotBreathe = false
    @Environment(\.colorScheme) private var colorScheme 

    var chartData: [WeightEntry] {
        Array(weightHistory.prefix(10)).reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weight Dynamics").font(.title3).bold().foregroundColor(colorScheme == .dark ? .white : .black)
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
        .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white) 
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)) 
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2) 
        .padding(.horizontal, 20)
    }
}

struct UserMetricsOverviewCard: View {
    var height: Int
    var age: Int
    var weight: Double
    var onEdit: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LocalizedStringKey("Basic Metrics"))
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? themeManager.current.primaryText : .black)
                Spacer()
                Button(action: onEdit) {
                    Text(LocalizedStringKey("Edit"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.current.primaryAccent)
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                metricBox(title: "Age", value: "\(age)", unit: "yrs", icon: "calendar")
                metricBox(title: "Height", value: "\(height)", unit: "cm", icon: "ruler")
                metricBox(title: "Weight", value: String(format: "%.1f", weight), unit: "kg", icon: "scalemass")
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func metricBox(title: LocalizedStringKey, value: String, unit: LocalizedStringKey, icon: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(themeManager.current.secondaryAccent)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.current.secondaryText)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.current.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(unit)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.current.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? themeManager.current.surface : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
    }
}


struct ProfileBreathingBackground: View {
    @State private var phase = false
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(red: 0.05, green: 0.05, blue: 0.07) : Color(UIColor.systemGroupedBackground)).edgesIgnoringSafeArea(.all)

            Circle()
                .fill(Color.red.opacity(colorScheme == .dark ? 0.08 : 0.03))
                .frame(width: 350, height: 350)
                .blur(radius: 120)
                .offset(x: phase ? 40 : -40, y: phase ? -30 : 30)
                .scaleEffect(phase ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: phase)
                .onAppear { phase = true }
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

struct AllAchievementsView: View {
    let achievements: [Achievement]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var unlocked: [Achievement] { achievements.filter { $0.isUnlocked } }
    var locked: [Achievement] { achievements.filter { !$0.isUnlocked } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                if !unlocked.isEmpty {
                    Text("Unlocked Trophies")
                        .font(.title2).bold()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.horizontal)

                    LazyVStack(spacing: 12) {
                        ForEach(unlocked) { achievement in
                            AchievementListRow(achievement: achievement)
                        }
                    }
                    .padding(.horizontal)
                }

                if !locked.isEmpty {
                    Text("In Progress")
                        .font(.title2).bold()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.horizontal)
                        .padding(.top, 10)

                    LazyVStack(spacing: 12) {
                        ForEach(locked) { achievement in
                            AchievementListRow(achievement: achievement)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 20)
        }
        .background(colorScheme == .dark ? Color(red: 0.05, green: 0.05, blue: 0.07) : Color(UIColor.systemGroupedBackground))
        .navigationTitle("All Trophies")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AchievementListRow: View {
    let achievement: Achievement
    @Environment(\.colorScheme) private var colorScheme

    private var glowColor: Color {
        guard achievement.isUnlocked else { return .gray }
        switch achievement.tier {
        case .none: return .clear
        case .bronze: return .orange
        case .silver: return .cyan
        case .gold: return .yellow
        case .diamond: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 16) {

            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? glowColor.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                    .font(.title2)
                    .foregroundColor(achievement.isUnlocked ? glowColor : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                    .lineLimit(3).minimumScaleFactor(0.8).allowsTightening(true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if achievement.isUnlocked {
                    Text(achievement.tier.name)
                        .font(.caption).bold()
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(glowColor.opacity(0.2))
                        .foregroundColor(glowColor)
                        .clipShape(Capsule())
                } else {
                    Text(achievement.progress)
                        .font(.caption).bold()
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2)
    }
}

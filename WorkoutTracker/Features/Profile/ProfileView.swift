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

    @Environment(UnitsManager.self) var unitsManager
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(ProfileViewModel.self) private var profileVM
    @Environment(UserStatsViewModel.self) private var userStatsViewModel

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?

    @State private var isAppeared = false

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

                        trackingNavigationSection

                        if !profileVM.cachedAchievements.isEmpty {
                            AchievementsCarousel(achievements: profileVM.cachedAchievements)
                        }

                        if !profileVM.cachedPersonalRecords.isEmpty {
                            PersonalRecordsView(records: profileVM.cachedPersonalRecords, unitsManager: unitsManager)
                        }

                        if !weightHistory.isEmpty {
                            BodyProgressChartView(weightHistory: weightHistory, unitsManager: unitsManager)
                        }

                        BodyStatsView(height: $userHeight, age: $userAge)

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
                    destination: AnyView(WeightHistoryView())
                )

                ProfileMenuCard(
                    title: "Body Measurements",
                    subtitle: "Muscle volumes and fat percentage",
                    icon: "ruler.fill",
                    color: themeManager.current.primaryAccent,
                    destination: AnyView(BodyMeasurementsView())
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
}

struct ProfileMenuCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: AnyView

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
                        .lineLimit(2)
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
                }
            }

            VStack(spacing: 4) {
                TextField("Athlete", text: $userName)
                    .font(.title2).bold()
                    .foregroundColor(colorScheme == .dark ? .white : .black) 
                    .multilineTextAlignment(.center)

                Text("@" + (userName.isEmpty ? "athlete" : userName.lowercased().replacingOccurrences(of: " ", with: "_")))
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .gray) 
            }
        }
    }
}

struct LevelProgressBar: View {
    let progressManager: ProgressManager
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        let progress = CGFloat(progressManager.progressPercentage)

        VStack(spacing: 12) {
            HStack {
                Text("Level \(progressManager.level)")
                    .font(.caption).bold()
                    .foregroundColor(progress > 0 ? .orange : .gray)
                Spacer()
                Text("\(progressManager.currentXPInLevel) XP")
                    .font(.subheadline).bold()
                    .foregroundColor(.red)
                Spacer()
                Text("Level \(progressManager.level + 1)")
                    .font(.caption).bold()
                    .foregroundColor(.gray)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)) 
                        .frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(colors: [.orange, .red, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 12)
                        .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 0)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white) 
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)) 
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2) 
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
                Text("Начальный вес").font(.caption).foregroundColor(.gray)
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
                Text("Сейчас").font(.caption).foregroundColor(.gray)
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

struct AchievementsCarousel: View {
    let achievements: [Achievement]
    @Environment(\.colorScheme) private var colorScheme 

    @State private var currentIndex: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        let total = CGFloat(achievements.count)
        let current = currentIndex - (dragOffset / 250)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                Text("Ваши трофеи (Свайп)")
                    .font(.title3).bold()
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
                NavigationLink(destination: AllAchievementsView(achievements: achievements)) {
                    Text("Все")
                        .font(.subheadline).bold()
                        .foregroundColor(.blue)
                }
            }
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
            Text("Личные рекорды")
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
                .lineLimit(1)
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
                Text("Динамика веса").font(.title3).bold().foregroundColor(colorScheme == .dark ? .white : .black) 
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

struct BodyStatsView: View {
    @Binding var height: Int
    @Binding var age: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            StatAdjuster(title: "Рост", value: "\(height)", unit: "см", onMinus: { height -= 1 }, onPlus: { height += 1 })
            StatAdjuster(title: "Возраст", value: "\(age)", unit: "лет", onMinus: { age -= 1 }, onPlus: { age += 1 })
        }
        .padding(.horizontal, 20)
    }
}

struct StatAdjuster: View {
    var title: String; var value: String; var unit: String
    var onMinus: () -> Void; var onPlus: () -> Void
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.caption).foregroundColor(.gray)
            HStack(spacing: 0) {
                Text(value).font(.system(size: 20, weight: .bold)).monospacedDigit()
                Text(unit).font(.caption).foregroundColor(.gray).padding(.leading, 2)
            }
            .foregroundColor(colorScheme == .dark ? .white : .black) 

            HStack(spacing: 16) {
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); withAnimation { onMinus() } }) { Image(systemName: "minus.circle.fill").foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .gray.opacity(0.5)) } 
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); withAnimation { onPlus() } }) { Image(systemName: "plus.circle.fill").foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .gray.opacity(0.5)) } 
            }
            .font(.title3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white)) 
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)) 
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2) 
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
                    Text("Разблокированные трофеи")
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
                    Text("В процессе")
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
        .navigationTitle("Все трофеи")
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
                    .lineLimit(2)
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

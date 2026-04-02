
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
    
    @State private var profileVM: ProfileViewModel?
    @State private var userStatsViewModel: UserStatsViewModel?
    
    @State private var selectedAchievement: Achievement?
    @State private var showingWeightHistory = false
    @State private var showingMeasurements = false
    @State private var showEditWeight = false
    @State private var newWeightString = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    
    var body: some View {
        ZStack {
            NavigationStack {
                mainContent
            }
            if let achievement = selectedAchievement {
                AchievementPopupView(achievement: achievement) { withAnimation { selectedAchievement = nil } }
                    .transition(.opacity.combined(with: .scale(scale: 0.9))).zIndex(100)
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if let pVM = profileVM, let usVM = userStatsViewModel {
            ScrollView {
                VStack(spacing: 25) {
                    headerSection(usVM: usVM)
                    if let forecast = pVM.topForecast { forecastBanner(forecast) }
                    achievementsSection(pVM: pVM)
                    Divider()
                    recordsSection(pVM: pVM)
                }.padding(.bottom, 40)
            }
            .navigationTitle(LocalizedStringKey("Profile"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(LocalizedStringKey("Close")) { dismiss() } } }
            .sheet(isPresented: $showingWeightHistory) { WeightHistoryView().environment(usVM) }
            .sheet(isPresented: $showingMeasurements) { BodyMeasurementsView().environment(usVM) }
            .alert(LocalizedStringKey("Update Body Weight"), isPresented: $showEditWeight) {
                TextField("Weight", text: $newWeightString).keyboardType(.decimalPad)
                Button("Save") { saveNewWeight(usVM: usVM) }
                Button("Cancel", role: .cancel) { }
            } message: { Text("Enter your current weight in \(unitsManager.weightUnitString())") }
            .onAppear { loadInitialData(pVM: pVM, usVM: usVM) }
        } else {
            ProgressView("Loading Profile...")
                .task {
                    self.profileVM = di.makeProfileViewModel()
                    self.userStatsViewModel = di.makeUserStatsViewModel()
                }
        }
    }
    
    @ViewBuilder
    private func headerSection(usVM: UserStatsViewModel) -> some View {
        VStack(spacing: 15) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                if let profileImage {
                    Image(uiImage: profileImage).resizable().scaledToFill().frame(width: 100, height: 100).clipShape(Circle()).overlay(Circle().stroke(Color.blue, lineWidth: 3))
                } else {
                    Text(userAvatar.isEmpty ? "🦍" : userAvatar).font(.system(size: 60)).frame(width: 100, height: 100).background(Color.gray.opacity(0.1)).clipShape(Circle()).overlay(Circle().stroke(Color.blue, lineWidth: 3))
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in handlePhotoSelection(newItem) }
            
            VStack(spacing: 8) {
                TextField("Fitness Enthusiast", text: $userName).font(.title2).bold().multilineTextAlignment(.center)
                let displayWeight = userBodyWeight == 0.0 ? 75.0 : userBodyWeight
                let convertedWeight = unitsManager.convertFromKilograms(displayWeight)
                HStack(spacing: 8) {
                    Text("\(LocalizationHelper.shared.formatDecimal(convertedWeight)) \(unitsManager.weightUnitString())").font(.title3).foregroundColor(.blue)
                    Button { newWeightString = LocalizationHelper.shared.formatDecimal(convertedWeight); showEditWeight = true } label: { Image(systemName: "pencil").font(.subheadline).foregroundColor(.blue) }
                }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue.opacity(0.1)).cornerRadius(8)
                HStack(spacing: 12) {
                    Button { showingWeightHistory = true } label: { HStack { Image(systemName: "scalemass"); Text(LocalizedStringKey("Weight Tracking")) }.font(.caption).foregroundColor(.blue).padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue.opacity(0.1)).cornerRadius(8) }
                    Button { showingMeasurements = true } label: { HStack { Image(systemName: "ruler"); Text(LocalizedStringKey("Body Measurements")) }.font(.caption).foregroundColor(.purple).padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue.opacity(0.1)).cornerRadius(8) }
                }
            }
        }.padding(.top, 20)
    }
    
    @ViewBuilder
    private func forecastBanner(_ forecast: ProgressForecast) -> some View {
        let convertedWeight = unitsManager.convertFromKilograms(forecast.predictedMax)
        let weightStr = convertedWeight.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", convertedWeight) : String(format: "%.1f", convertedWeight)
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "sparkles").foregroundColor(.yellow); Text("AI Forecast").font(.headline).fontWeight(.bold).foregroundColor(.white) }
            Text(String(localized: "In \(forecast.timeframe) your \(forecast.exerciseName) is predicted to reach \(weightStr) \(unitsManager.weightUnitString())!")).font(.subheadline).foregroundColor(.white.opacity(0.9)).minimumScaleFactor(0.8)
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(LinearGradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(16).shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4).padding(.horizontal)
    }
    
    @ViewBuilder
    private func achievementsSection(pVM: ProfileViewModel) -> some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("Achievements")).font(.title3).bold().padding(.horizontal)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(pVM.cachedAchievements) { achievement in
                    AchievementBadge(achievement: achievement)
                        .onTapGesture {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedAchievement = achievement
                            }
                        }
                }
            }.padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func recordsSection(pVM: ProfileViewModel) -> some View {
        if !pVM.cachedPersonalRecords.isEmpty {
            VStack(alignment: .leading, spacing: 15) {
                Text(LocalizedStringKey("Personal Records")).font(.title3).bold().padding(.horizontal)
                VStack(spacing: 0) {
                    ForEach(pVM.cachedPersonalRecords) { record in
                        HStack {
                            Image(systemName: getIcon(record.type)).foregroundColor(getColor(record.type)).frame(width: 30)
                            Text(LocalizedStringKey(record.exerciseName)).font(.body)
                            Spacer()
                            Text(record.value).font(.headline).foregroundColor(.blue)
                        }.padding()
                        if record.id != pVM.cachedPersonalRecords.last?.id { Divider().padding(.leading, 50) }
                    }
                }.background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).padding(.horizontal)
            }
        } else { Text(LocalizedStringKey("Complete workouts to see your records!")).font(.caption).foregroundColor(.secondary) }
    }
    
    private func saveNewWeight(usVM: UserStatsViewModel) {
        let formatter = NumberFormatter(); formatter.numberStyle = .decimal
        if let number = formatter.number(from: newWeightString)?.doubleValue ?? Double(newWeightString.replacingOccurrences(of: ",", with: ".")) {
            let weightKg = unitsManager.convertToKilograms(number)
            userBodyWeight = weightKg
            Task { await usVM.addWeightEntry(weight: weightKg) }
        }
    }
    
    private func loadInitialData(pVM: ProfileViewModel, usVM: UserStatsViewModel) {
        profileImage = ProfileImageManager.shared.loadImage()
        Task {
            // ✅ ИСПРАВЛЕНИЕ: Передали modelContainer
            await pVM.loadProfileData(stats: userStats.first ?? UserStats(), currentStreak: dashboardViewModel.streakCount, unitsManager: unitsManager, modelContainer: context.container)
        }
        if weightHistory.isEmpty && userBodyWeight > 0.0 { Task { await usVM.addWeightEntry(weight: userBodyWeight) } }
    }
    
    private func handlePhotoSelection(_ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                await MainActor.run { profileImage = uiImage; ProfileImageManager.shared.saveImage(uiImage) }
            }
        }
    }
    
    private func getIcon(_ type: ExerciseType) -> String { type == .strength ? "dumbbell.fill" : (type == .cardio ? "figure.run" : "stopwatch.fill") }
    private func getColor(_ type: ExerciseType) -> Color { type == .strength ? .blue : (type == .cardio ? .orange : .purple) }
}

// MARK: - Subviews for Achievements

struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(width: 80, height: 80)
                
                if achievement.isUnlocked {
                    Circle()
                        .strokeBorder(tierColor(achievement.tier), lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .shadow(color: tierColor(achievement.tier).opacity(0.5), radius: 5, x: 0, y: 0)
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 35))
                        .foregroundColor(tierColor(achievement.tier))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
            
            if !achievement.isUnlocked && !achievement.progress.isEmpty {
                Text(achievement.progress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 140)
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

struct AchievementPopupView: View {
    let achievement: Achievement
    let onClose: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 150, height: 150)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 80))
                        .foregroundColor(tierColor(achievement.tier))
                        .shadow(color: tierColor(achievement.tier).opacity(0.8), radius: 20, x: 0, y: 0)
                }
                .padding(.bottom, 20)
                
                Text("🏆")
                    .font(.largeTitle)
                
                Text("Achievement Unlocked!")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(2)
                
                Text(achievement.title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                
                Text("Level: \(achievement.tier.name)")
                    .font(.headline)
                    .foregroundColor(tierColor(achievement.tier))
                    .padding(.top, 20)
                
                Button(action: onClose) {
                    Text("Cool!")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(width: 200)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                }
                .padding(.top, 30)
            }
        }
        .onAppear {
            isAnimating = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
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

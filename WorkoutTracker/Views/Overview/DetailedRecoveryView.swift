//
//  DetailedRecoveryView.swift
//  WorkoutTracker
//

//
//  DetailedRecoveryView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData

// MARK: - Helper Model
struct MuscleStatusItem: Identifiable {
    let id = UUID()
    let name: String
    let percent: Int
}

// MARK: - Main View
struct DetailedRecoveryView: View {
    
    // MARK: - Environment & Storage
    @Environment(\.modelContext) private var context
    @Environment(DIContainer.self) private var di // ✅ Заменили WorkoutViewModel на DIContainer
    @Environment(TutorialManager.self) var tutorialManager
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @AppStorage("userGender") private var userGender = "male"
    @AppStorage("userRecoveryHours") private var storedRecoveryHours: Double = 48.0
    @State private var localRecoveryHours: Double = 48.0
    @State private var inMemoryWorkouts: [Workout] = []
    
    private var musclesData: [MuscleStatusItem] {
        return dashboardViewModel.recoveryStatus.map {
            let displayName = MuscleDisplayHelper.getDisplayName(for: $0.muscleGroup)
            return MuscleStatusItem(name: displayName, percent: $0.recoveryPercentage)
        }.sorted { lhs, rhs in
            if lhs.percent != rhs.percent { return lhs.percent < rhs.percent }
            else { return lhs.name < rhs.name }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection
                muscleListSection
            }
            .padding(.bottom)
        }
        .navigationTitle(LocalizedStringKey("Muscle Status"))
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            localRecoveryHours = storedRecoveryHours
            loadWorkoutsIntoMemory()
            recalculateRecoveryLocal(hours: localRecoveryHours)
        }
        .onChange(of: localRecoveryHours) { _, newValue in
            recalculateRecoveryLocal(hours: newValue)
        }
    }
    
    private func loadWorkoutsIntoMemory() {
        let cutoffDate = Date.now.addingTimeInterval(-((96.0 + 24.0) * 3600))
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endTime != nil && $0.date >= cutoffDate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        inMemoryWorkouts = (try? context.fetch(descriptor)) ?? []
    }
    
    private func recalculateRecoveryLocal(hours: Double) {
        // ✅ ИСПРАВЛЕНИЕ: Вызов асинхронного сервиса
        Task {
            let newRecoveryStatus = await di.analyticsService.calculateRecovery(hours: hours, workouts: inMemoryWorkouts)
            await MainActor.run {
                dashboardViewModel.recoveryStatus = newRecoveryStatus
            }
        }
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("Recovery Settings")).font(.headline)
            
            VStack {
                HStack {
                    Text(LocalizedStringKey("Full Recovery Time:")).foregroundColor(.secondary)
                    Spacer()
                    Text(LocalizedStringKey("\(Int(localRecoveryHours)) hours")).bold().foregroundColor(.blue)
                }
                
                Slider(
                    value: $localRecoveryHours,
                    in: 12...96,
                    step: 4,
                    onEditingChanged: { isEditing in
                        if !isEditing { storedRecoveryHours = localRecoveryHours }
                    }
                )
                .tint(.blue)
            }
            .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
            
            Text(LocalizedStringKey("Adjust this based on how fast you recover. Standard is 48h.")).font(.caption).foregroundColor(.gray).padding(.horizontal, 5)
        }
        .padding(.horizontal).padding(.top)
        .spotlight(step: .recoverySlider, manager: tutorialManager, text: "Adjust your recovery speed here. Tap to finish.", alignment: .top, yOffset: -20)
        .onTapGesture { if tutorialManager.currentStep == .recoverySlider { tutorialManager.complete() } }
    }
    
    private var muscleListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("Full Muscle Breakdown")).font(.headline).foregroundColor(.secondary).padding(.horizontal)
            LazyVStack(spacing: 12) {
                ForEach(musclesData) { item in MuscleStatusRow(name: item.name, percentage: item.percent) }
            }.padding(.horizontal)
        }
    }
}

// MARK: - Subviews (Row)

struct MuscleStatusRow: View {
    let name: String
    let percentage: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(name))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(LocalizedStringKey(statusText))
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Text("\(percentage)%")
                    .bold()
                    .monospacedDigit()
                    .foregroundColor(statusColor)
                
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 6)
                    .overlay(
                        GeometryReader { geo in
                            Capsule()
                                .fill(statusColor)
                                .frame(width: geo.size.width * (Double(percentage) / 100.0))
                        }
                    )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: percentage < 100 ? .black.opacity(0.05) : .clear, radius: 2, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        if percentage < 50 { return .red }
        if percentage < 80 { return .orange }
        return .green
    }
    
    private var statusText: String {
        if percentage >= 100 { return NSLocalizedString("Fully Recovered", comment: "") }
        if percentage >= 80 { return NSLocalizedString("Ready to Train", comment: "") }
        if percentage >= 50 { return NSLocalizedString("Recovering...", comment: "") }
        return NSLocalizedString("Exhausted", comment: "")
    }
}

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
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var tutorialManager: TutorialManager
    
    // 1. Долгосрочное хранилище
    @AppStorage("userRecoveryHours") private var storedRecoveryHours: Double = 48.0
    
    // 2. Локальное состояние для плавности интерфейса
    @State private var localRecoveryHours: Double = 48.0
    
    // 🎼 МАЭСТРО: Кэшируем тренировки в оперативной памяти, чтобы не насиловать базу данных при скролле ползунка
    @State private var inMemoryWorkouts: [Workout] = []
    
    // MARK: - Data Source
    private var musclesData: [MuscleStatusItem] {
        return viewModel.recoveryStatus.map {
            // Fallback translation if not found in helper
            let displayName = MuscleDisplayHelper.getDisplayName(for: $0.muscleGroup)
            return MuscleStatusItem(name: displayName, percent: $0.recoveryPercentage)
        }.sorted { lhs, rhs in
            if lhs.percent != rhs.percent { return lhs.percent < rhs.percent }
            else { return lhs.name < rhs.name }
        }
    }
    
    // MARK: - Body
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
        
        // Инициализация при открытии экрана
        .onAppear {
            localRecoveryHours = storedRecoveryHours
            
            // 🎼 Загружаем ОДИН раз
            loadWorkoutsIntoMemory()
            
            // Считаем первичное состояние из ОЗУ
            recalculateRecoveryLocal(hours: localRecoveryHours)
        }
        
        // СЛЕЖЕНИЕ ЗА ИЗМЕНЕНИЯМИ (Live Update из ОЗУ)
        .onChange(of: localRecoveryHours) { _, newValue in
            recalculateRecoveryLocal(hours: newValue)
        }
    }
    
    // MARK: - Local Memory Calculation
    
    /// Загружает тренировки за максимально возможный период (96 часов + 24 часа запас)
    private func loadWorkoutsIntoMemory() {
        // Максимальное значение слайдера (96) + запас на длительность самой тренировки (24)
        let cutoffDate = Date.now.addingTimeInterval(-((96.0 + 24.0) * 3600))
        
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.endTime != nil && $0.date >= cutoffDate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        inMemoryWorkouts = (try? context.fetch(descriptor)) ?? []
    }
    
    /// 🎼 Быстрая математика в памяти, никаких обращений к диску
    private func recalculateRecoveryLocal(hours: Double) {
        // Калькулятор берет данные напрямую из inMemoryWorkouts (0 задержек, 0 I/O)
        let newRecoveryStatus = RecoveryCalculator.calculate(hours: hours, workouts: inMemoryWorkouts)
        viewModel.recoveryStatus = newRecoveryStatus
    }
    
    // MARK: - View Components
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("Recovery Settings")).font(.headline)
            
            VStack {
                HStack {
                    Text(LocalizedStringKey("Full Recovery Time:"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(LocalizedStringKey("\(Int(localRecoveryHours)) hours"))
                        .bold()
                        .foregroundColor(.blue)
                }
                
                Slider(
                    value: $localRecoveryHours,
                    in: 12...96,
                    step: 4,
                    onEditingChanged: { isEditing in
                        if !isEditing {
                            storedRecoveryHours = localRecoveryHours
                        }
                    }
                )
                .tint(.blue)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            Text(LocalizedStringKey("Adjust this based on how fast you recover. Standard is 48h."))
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 5)
        }
        .padding(.horizontal)
        .padding(.top)
        .spotlight(
            step: .recoverySlider,
            manager: tutorialManager,
            text: "Adjust your recovery speed here. Tap to finish.",
            alignment: .top,
            yOffset: -20
        )
        .onTapGesture {
            if tutorialManager.currentStep == .recoverySlider {
                tutorialManager.complete()
            }
        }
    }
    
    private var muscleListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("Full Muscle Breakdown"))
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            LazyVStack(spacing: 12) {
                ForEach(musclesData) { item in
                    MuscleStatusRow(name: item.name, percentage: item.percent)
                }
            }
            .padding(.horizontal)
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

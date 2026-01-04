//
//  DetailedRecoveryView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 26.12.25.
//

internal import SwiftUI

// MARK: - Helper Model
struct MuscleStatusItem: Identifiable {
    let id = UUID()
    let name: String
    let percent: Int
}

// MARK: - Main View
struct DetailedRecoveryView: View {
    
    // MARK: - Environment & Storage
    @EnvironmentObject var viewModel: WorkoutViewModel
    @EnvironmentObject var tutorialManager: TutorialManager
    
    // 1. Переименовали для ясности: это "Долгосрочное хранилище"
    @AppStorage("userRecoveryHours") private var storedRecoveryHours: Double = 48.0
    
    // 2. Локальное состояние для плавности интерфейса
    @State private var localRecoveryHours: Double = 48.0
    
    // MARK: - Data Source
    private var musclesData: [MuscleStatusItem] {
        return viewModel.recoveryStatus.map {
            MuscleStatusItem(name: $0.muscleGroup, percent: $0.recoveryPercentage)
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
        .navigationTitle("Muscle Status")
        .background(Color(UIColor.systemGroupedBackground))
        
        // Инициализация при открытии экрана
        .onAppear {
            localRecoveryHours = storedRecoveryHours
            // Принудительно обновляем данные при входе, чтобы цифры были актуальны
            viewModel.calculateRecovery(hours: localRecoveryHours)
        }
        
        // СЛЕЖЕНИЕ ЗА ИЗМЕНЕНИЯМИ (Live Update)
        // Здесь мы только считаем математику для UI. Сохранять в память не нужно, чтобы не было лагов.
        .onChange(of: localRecoveryHours) { _, newValue in
            viewModel.calculateRecovery(hours: newValue)
        }
    }
    
    // MARK: - View Components
    private var settingsSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recovery Settings").font(.headline)
                
                VStack {
                    HStack {
                        Text("Full Recovery Time:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(localRecoveryHours)) hours")
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
                .background(Color.white)
                .cornerRadius(12)
                
                Text("Adjust this based on how fast you recover. Standard is 48h.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 5)
            }
            .padding(.horizontal)
            .padding(.top)
            // ИСПРАВЛЕНИЕ: Текст СВЕРХУ (alignment: .top) + отступ
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
            Text("Full Muscle Breakdown")
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
        if percentage >= 100 { return "Fully Recovered" }
        if percentage >= 80 { return "Ready to Train" }
        if percentage >= 50 { return "Recovering..." }
        return "Exhausted"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetailedRecoveryView()
            .environmentObject(WorkoutViewModel())
            .environmentObject(TutorialManager())
    }
}

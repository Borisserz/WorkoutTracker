//
//  DetailedRecoveryView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 26.12.25.
//

internal import SwiftUI

struct MuscleStatusItem: Identifiable {
    let id = UUID()
    let name: String
    let percent: Int
}

struct DetailedRecoveryView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // Сохраняем настройку в память телефона (ключ должен совпадать с тем, что в ViewModel)
    @AppStorage("userRecoveryHours") private var recoveryHours: Double = 48.0
    
    // Полный список всех мышц
    let allMuscleGroups = [
        "Trapezius", "Shoulders", "Chest", "Back", "Lower Back",
        "Biceps", "Triceps", "Forearms", "Abs", "Obliques",
        "Glutes", "Hamstrings", "Legs", "Calves"
    ]
    
    var musclesData: [MuscleStatusItem] {
        let data = allMuscleGroups.map { name -> MuscleStatusItem in
            let status = viewModel.recoveryStatus.first(where: { $0.muscleGroup == name })
            return MuscleStatusItem(name: name, percent: status?.recoveryPercentage ?? 100)
        }
        
        return data.sorted { lhs, rhs in
            if lhs.percent != rhs.percent {
                return lhs.percent < rhs.percent
            } else {
                return lhs.name < rhs.name
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // --- НОВЫЙ БЛОК: НАСТРОЙКА ВРЕМЕНИ ---
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recovery Settings")
                        .font(.headline)
                    
                    VStack {
                        HStack {
                            Text("Full Recovery Time:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(recoveryHours)) hours")
                                .bold()
                                .foregroundColor(.blue)
                        }
                        
                        // Слайдер от 12 до 96 часов (с шагом 4 часа)
                        Slider(value: $recoveryHours, in: 12...96, step: 4)
                            .tint(.blue)
                    }
                    .padding()
                    .background(Color.white) // Или Color(UIColor.secondarySystemBackground) для темной темы
                    .cornerRadius(12)
                    
                    Text("Adjust this based on how fast you recover. Standard is 48h.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 5)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // --- СПИСОК МЫШЦ ---
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
            .padding(.bottom)
        }
        .navigationTitle("Muscle Status")
        .background(Color(UIColor.systemGroupedBackground))
        // ВАЖНО: Следим за изменением слайдера и пересчитываем данные
        .onChange(of: recoveryHours) { _ in
            viewModel.calculateRecovery()
        }
    }
}

// --- ЯЧЕЙКА СПИСКА ---
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
    
    var statusColor: Color {
        if percentage < 50 { return .red }
        if percentage < 80 { return .orange }
        return .green
    }
    
    var statusText: String {
        if percentage >= 100 { return "Fully Recovered" }
        if percentage >= 80 { return "Ready to Train" }
        if percentage >= 50 { return "Recovering..." }
        return "Exhausted"
    }
}

#Preview {
    NavigationStack {
        DetailedRecoveryView()
            .environmentObject(WorkoutViewModel())
    }
}

//
//  DetailedRecoveryView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 26.12.25.
//

import SwiftUI

struct DetailedRecoveryView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Вставляем нашего человечка сюда (красиво и наглядно)
                BodyHeatmapView()
                    .frame(height: 400)
                    .padding(.vertical)
                
                Divider()
                
                // 2. Полный список всех мышц
                VStack(alignment: .leading, spacing: 15) {
                    Text("All Muscles Breakdown")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)
                    
                    // Сортируем: сначала самые уставшие
                    let sortedMuscles = viewModel.recoveryStatus.sorted { $0.recoveryPercentage < $1.recoveryPercentage }
                    
                    if sortedMuscles.isEmpty {
                        Text("No data yet. Start training!")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(sortedMuscles, id: \.muscleGroup) { status in
                            HStack {
                                Text(status.muscleGroup)
                                    .font(.headline)
                                Spacer()
                                Text("\(status.recoveryPercentage)%")
                                    .bold()
                                    .foregroundColor(recoveryColor(status.recoveryPercentage))
                                
                                // Маленький индикатор
                                Circle()
                                    .fill(recoveryColor(status.recoveryPercentage))
                                    .frame(width: 10, height: 10)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .navigationTitle("Muscle Status")
    }
    
    func recoveryColor(_ percentage: Int) -> Color {
        if percentage < 50 { return .red }
        if percentage < 80 { return .orange }
        return .green
    }
}

#Preview {
    DetailedRecoveryView()
}

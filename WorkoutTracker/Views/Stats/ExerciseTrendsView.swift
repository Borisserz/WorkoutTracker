//
//  ExerciseTrendsView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Отображение трендов по упражнениям (рост/падение)

internal import SwiftUI

struct ExerciseTrendsView: View {
    let trends: [WorkoutViewModel.ExerciseTrend]
    
    var body: some View {
        if trends.isEmpty {
            Text(LocalizedStringKey("No exercise trends available"))
                .foregroundColor(.secondary)
                .frame(height: 100, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // Показываем топ-5: приоритет растущим трендам, но также включаем значимые падения
                let topTrends = selectTopTrends(trends, limit: 5)
                ForEach(topTrends) { trend in
                    ExerciseTrendRow(trend: trend)
                }
            }
        }
    }
    
    /// Выбирает топ трендов: приоритет растущим, но также включает значимые падения
    private func selectTopTrends(_ trends: [WorkoutViewModel.ExerciseTrend], limit: Int) -> [WorkoutViewModel.ExerciseTrend] {
        let growing = trends.filter { $0.trend == .growing }
        let declining = trends.filter { $0.trend == .declining }
        let stable = trends.filter { $0.trend == .stable }
        
        var selected: [WorkoutViewModel.ExerciseTrend] = []
        
        // Сначала добавляем растущие (до 3 штук или пока не заполним лимит)
        selected.append(contentsOf: Array(growing.prefix(min(3, limit))))
        
        // Затем добавляем падающие (если есть место)
        if selected.count < limit {
            let remaining = limit - selected.count
            selected.append(contentsOf: Array(declining.prefix(remaining)))
        }
        
        // Если все еще есть место, добавляем стабильные с наибольшими изменениями
        if selected.count < limit {
            let remaining = limit - selected.count
            selected.append(contentsOf: Array(stable.prefix(remaining)))
        }
        
        return selected
    }
}

struct ExerciseTrendRow: View {
    let trend: WorkoutViewModel.ExerciseTrend
    
    var body: some View {
        HStack {
            Image(systemName: trend.trend.icon)
                .foregroundColor(trend.trend.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trend.exerciseName)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text("\(Int(trend.previousValue)) kg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(trend.currentValue)) kg")
                        .font(.caption)
                        .bold()
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(trend.changePercentage, specifier: "%.0f")%")
                    .font(.headline)
                    .foregroundColor(trend.trend.color)
                
                Text(trend.trend == .growing ? LocalizedStringKey("↑ Growing") : trend.trend == .declining ? LocalizedStringKey("↓ Declining") : LocalizedStringKey("→ Stable"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ExerciseTrendsView(trends: [])
}


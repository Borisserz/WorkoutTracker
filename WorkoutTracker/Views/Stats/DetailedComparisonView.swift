//
//  DetailedComparisonView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Детальное сравнение с предыдущим периодом

internal import SwiftUI

struct DetailedComparisonView: View {
    let comparisons: [WorkoutViewModel.DetailedComparison]
    let period: String
    
    var body: some View {
        if comparisons.isEmpty {
            EmptyStateView(
                icon: "chart.bar.xaxis",
                title: LocalizedStringKey("No comparison data available"),
                message: LocalizedStringKey("Complete more workouts to see detailed comparisons between periods. Track your progress over time!")
            )
            .frame(height: 150)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(comparisons, id: \.metric) { comparison in
                    DetailedComparisonRow(comparison: comparison)
                }
            }
        }
    }
}

struct DetailedComparisonRow: View {
    let comparison: WorkoutViewModel.DetailedComparison
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comparison.metric)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: comparison.trend.icon)
                    .foregroundColor(comparison.trend.color)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Previous"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatValue(comparison.previousValue))
                        .font(.subheadline)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Current"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatValue(comparison.currentValue))
                        .font(.subheadline)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(comparison.changePercentage >= 0 ? "+" : "")\(comparison.changePercentage, specifier: "%.1f")%")
                        .font(.headline)
                        .foregroundColor(comparison.trend.color)
                    
                    Text(formatValue(abs(comparison.change)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatValue(_ value: Double) -> String {
        return LocalizationHelper.shared.formatSmart(value)
    }
}

#Preview {
    DetailedComparisonView(comparisons: [], period: "Month")
}


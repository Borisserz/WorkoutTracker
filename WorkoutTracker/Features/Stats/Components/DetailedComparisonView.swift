//
//  DetailedComparisonView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Детальное сравнение с предыдущим Periodом

internal import SwiftUI

struct DetailedComparisonView: View {
    let comparisons: [DetailedComparison]
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
    let comparison: DetailedComparison
    
    private func iconAndColor(for metric: String) -> (icon: String, color: Color) {
        let m = metric.lowercased()
        if m.contains("workout") { return ("figure.run", .blue) }
        if m.contains("volume") { return ("scalemass.fill", .purple) }
        if m.contains("distance") { return ("map.fill", .orange) }
        if m.contains("time") { return ("stopwatch.fill", .cyan) }
        return ("chart.bar.fill", .gray)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            let style = iconAndColor(for: comparison.metric)
            
            ZStack {
                Circle().fill(style.color.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: style.icon).font(.title3).foregroundColor(style.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(comparison.metric))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Text(LocalizationHelper.shared.formatSmart(comparison.previousValue))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(LocalizationHelper.shared.formatSmart(comparison.currentValue))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            let isPositive = comparison.changePercentage >= 0
            Text("\(isPositive ? "+" : "")\(comparison.changePercentage, specifier: "%.1f")%")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isPositive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .foregroundColor(isPositive ? .green : .red)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    DetailedComparisonView(comparisons: [], period: "Month")
}


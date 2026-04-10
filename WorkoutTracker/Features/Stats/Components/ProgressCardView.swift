// ProgressCardView.swift
internal import SwiftUI
import Charts

struct ProgressCardView: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    let currentValue: Double
    let previousValue: Double
    
    // Вычисляем процентное изменение
    var percentageChange: Double {
        if previousValue == 0 {
            return currentValue > 0 ? 100.0 : 0.0
        }
        return (currentValue - previousValue) / previousValue * 100.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .clipShape(Circle())
                
                Text(LocalizedStringKey(title))
                    .font(.headline)
                
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 5) {
                Image(systemName: percentageChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.bold())
                
                Text("\(percentageChange, specifier: "%.0f")%")
                    .font(.caption.bold())
                
                Text("vs last period")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(percentageChange >= 0 ? .green : .red)
            
            Chart {
                // Линия прошлого значения
                RuleMark(y: .value("Previous", previousValue))
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                
                // Столбец текущего значения
                BarMark(
                    x: .value("Period", "Current"),
                    y: .value("Value", currentValue)
                )
                .foregroundStyle(color.gradient)
                .cornerRadius(4)
            }
            .frame(height: 50)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

//
//  ProgressForecastView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Отображение прогноза прогресса

internal import SwiftUI

struct ProgressForecastView: View {
    let forecasts: [ProgressForecast]
    
    var body: some View {
        if forecasts.isEmpty {
            Text(LocalizedStringKey("Not enough data for forecasting"))
                .foregroundColor(.secondary)
                .frame(height: 100, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(forecasts.prefix(5))) { forecast in
                    ProgressForecastRow(forecast: forecast)
                }
            }
        }
    }
}

struct ProgressForecastRow: View {
    let forecast: ProgressForecast
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(forecast.exerciseName)
                    .font(.headline)
                
                Spacer()
                
                // Индикатор уверенности с цветовой кодировкой
                HStack(spacing: 4) {
                    Circle()
                        .fill(forecast.confidence >= 70 ? Color.green : 
                              forecast.confidence >= 50 ? Color.orange : Color.red)
                        .frame(width: 8, height: 8)
                    Text("\(forecast.confidence)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Current"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(LocalizedStringKey("\(Int(forecast.currentMax)) kg"))
                        .font(.subheadline)
                        .bold()
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Predicted"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(LocalizedStringKey("\(Int(forecast.predictedMax)) kg"))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(LocalizedStringKey("+\(Int(forecast.predictedMax - forecast.currentMax)) kg"))
                        .font(.caption)
                        .bold()
                        .foregroundColor(.green)
                    Text(LocalizedStringKey("in \(forecast.timeframe)"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Прогресс бар для визуализации
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.blue.gradient)
                        .frame(
                            width: geometry.size.width * min(1.0, forecast.predictedMax / max(forecast.currentMax, 1)),
                            height: 6
                        )
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ProgressForecastView(forecasts: [])
}


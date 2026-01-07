//
//  WeakPointsView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Отображение анализа слабых мест

internal import SwiftUI

struct WeakPointsView: View {
    let weakPoints: [WorkoutViewModel.WeakPoint]
    
    var body: some View {
        if weakPoints.isEmpty {
            EmptyStateView(
                icon: "checkmark.shield.fill",
                title: LocalizedStringKey("No weak points detected"),
                message: LocalizedStringKey("Great job! Your training is well-balanced. Keep up the excellent work!")
            )
            .frame(height: 150)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(weakPoints.prefix(5))) { weakPoint in
                    WeakPointRow(weakPoint: weakPoint)
                }
            }
        }
    }
}

struct WeakPointRow: View {
    let weakPoint: WorkoutViewModel.WeakPoint
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(weakPoint.muscleGroup)
                    .font(.headline)
                
                Text(weakPoint.recommendation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("\(weakPoint.frequency)x")
                        .font(.caption)
                        .bold()
                }
                .foregroundColor(.orange)
                
                Text(LocalizedStringKey("\(Int(weakPoint.averageVolume)) kg avg"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    WeakPointsView(weakPoints: [])
}


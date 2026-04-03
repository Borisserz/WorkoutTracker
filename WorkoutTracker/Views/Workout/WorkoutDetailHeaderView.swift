//
//  WorkoutDetailHeaderView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 1.04.26.
//

internal import SwiftUI

struct WorkoutDetailHeaderView: View {
    @Bindable var workout: Workout
    
    var body: some View {
        VStack(spacing: 20) {
            if workout.isActive {
                HStack {
                    Label(LocalizedStringKey("Live Workout"), systemImage: "record.circle")
                        .foregroundStyle(Color.accentColor).bold().blinking()
                    Spacer()
                    WorkoutTimerView(startDate: workout.date)
                }
                .padding().background(Color.accentColor.opacity(0.1)).cornerRadius(12)
            } else {
                HStack {
                    Image(systemName: "flag.checkered").foregroundColor(.accentColor)
                    Text(LocalizedStringKey("Completed")).bold()
                    Spacer()
                    Text(workout.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                }
                .padding().background(Color.accentColor.opacity(0.1)).cornerRadius(12)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("Duration")).font(.caption).foregroundColor(.secondary)
                    if workout.isActive { WorkoutTimerView(startDate: workout.date) }
                    else { Text(LocalizedStringKey("\(workout.durationSeconds / 60) min")).font(.title2).bold() }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(LocalizedStringKey("Avg Effort")).font(.caption).foregroundColor(.secondary)
                    Text("\(workout.effortPercentage)%").font(.title2).bold().foregroundColor(effortColor(percentage: workout.effortPercentage))
                }
            }
            .padding().background(Color.accentColor.opacity(0.05)).cornerRadius(10)
        }
        .zIndex(10)
    }
    
    private func effortColor(percentage: Int) -> Color {
        if percentage > 80 { return .red }
        if percentage > 50 { return .orange }
        return .green
    }
}
extension View {
    func blinking() -> some View {
        self.modifier(BlinkingTextModifier())
    }
}
struct WorkoutTimerView: View {
    let startDate: Date
    
    var body: some View {
        Text(startDate, style: .timer)
            .font(.title2)
            .bold()
            .monospacedDigit()
            .foregroundColor(.primary)
    }
}

// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/WorkoutDetailHeaderView.swift
// ============================================================


internal import SwiftUI

struct WorkoutDetailHeaderView: View {
    @Bindable var workout: Workout
    var viewModel: WorkoutDetailViewModel
    
    @Environment(UnitsManager.self) var unitsManager
    
    // ✅ FIX: Removed local completedSetsCount calculation.
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if workout.isActive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .symbolEffect(.pulse)
                            Text(LocalizedStringKey("Live Workout"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.red)
                        }
                        WorkoutTimerView(startDate: workout.date)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "flag.checkered").foregroundColor(.cyan)
                            Text(LocalizedStringKey("Completed"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.cyan)
                        }
                        Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.title3)
                            .fontWeight(.heavy)
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 50, height: 50)
                    Image(systemName: workout.isActive ? "bolt.fill" : "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            
            Divider().opacity(0.5)
                       
                       HStack {
                           VStack(alignment: .leading, spacing: 4) {
                               Text(LocalizedStringKey("🏋️ Total Lifted"))
                                   .font(.caption)
                                   .fontWeight(.bold)
                                   .foregroundColor(.secondary)
                                   .textCase(.uppercase)
                               
                               let volume = viewModel.workoutAnalytics.volume
                               let convertedVolume = unitsManager.convertFromKilograms(volume)
                               
                               HStack(alignment: .firstTextBaseline, spacing: 4) {
                                   Text("\(LocalizationHelper.shared.formatInteger(convertedVolume))")
                                       .font(.system(size: 28, weight: .heavy, design: .rounded))
                                       .foregroundColor(.primary)
                                       .contentTransition(.numericText())
                                   Text(unitsManager.weightUnitString())
                                       .font(.subheadline)
                                       .fontWeight(.bold)
                                       .foregroundColor(.secondary)
                               }
                           }
                           
                           Spacer()
                           
                           VStack(alignment: .trailing, spacing: 4) {
                               Text(LocalizedStringKey("Completed Sets"))
                                   .font(.caption)
                                   .fontWeight(.bold)
                                   .foregroundColor(.secondary)
                                   .textCase(.uppercase)
                               
                               // ✅ FIX: Bind directly to the ViewModel's reactive DTO
                               Text("\(viewModel.workoutAnalytics.completedSetsCount)")
                                   .font(.system(size: 28, weight: .heavy, design: .rounded))
                                   .foregroundColor(.cyan)
                                   .contentTransition(.numericText())
                           }
                       }
                   }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .zIndex(10)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.workoutAnalytics.volume)
               .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.workoutAnalytics.completedSetsCount) 
    }
}

// MARK: - WorkoutTimerView

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



internal import SwiftUI
import UIKit

struct WorkoutDetailHeaderView: View {
    @Bindable var workout: Workout
    var viewModel: WorkoutDetailViewModel

    @Environment(UnitsManager.self) var unitsManager
    @Environment(ThemeManager.self) private var themeManager

    private var workoutProgress: Double {
        let totalSets = workout.exercises.reduce(0) { sum, exercise in
            if exercise.isSuperset {
                return sum + exercise.subExercises.reduce(0) { $0 + $1.setsList.count }
            } else {
                return sum + exercise.setsList.count
            }
        }
        guard totalSets > 0 else { return 0.0 }
        return Double(viewModel.workoutAnalytics.completedSetsCount) / Double(totalSets)
    }

    var body: some View {
        HStack(alignment: .center) {
            // 1. Running Time
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.isActive ? "ВРЕМЯ" : "ДАТА")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)

                if workout.isActive {
                    WorkoutTimerView(startDate: workout.date)
                } else {
                    Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                }
            }

            Spacer()

            // 2. Volume Lifted
            VStack(alignment: .center, spacing: 4) {
                Text("ОБЩИЙ ВЕС")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)

                let volume = viewModel.workoutAnalytics.volume
                let convertedVolume = unitsManager.convertFromKilograms(volume)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(LocalizationHelper.shared.formatInteger(convertedVolume))")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .contentTransition(.numericText())

                    Text(unitsManager.weightUnitString())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PastelTheme.textSecondary)
                }
            }

            Spacer()

            // 3. Sets Progress
            VStack(alignment: .trailing, spacing: 4) {
                Text("СЕТЫ")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PastelTheme.pastelEmerald)

                    Text("\(viewModel.workoutAnalytics.completedSetsCount)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.workoutAnalytics.volume)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.workoutAnalytics.completedSetsCount)
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





internal import SwiftUI
import UIKit

struct WorkoutDetailHeaderView: View {
    @Bindable var workout: Workout
    var viewModel: WorkoutDetailViewModel

    @Environment(UnitsManager.self) var unitsManager
    @Environment(ThemeManager.self) private var themeManager

    var onFinish: (() -> Void)? = nil

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
        HStack(alignment: .center, spacing: 14) {
            // 1. Running Time
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.isActive ? "Running Time" : "Date")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
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
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.isActive ? "Total Volume Lifted" : "Volume")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)

                let volume = viewModel.workoutAnalytics.volume
                let convertedVolume = unitsManager.convertFromKilograms(volume)
                let displayVolume = max(0, convertedVolume)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(LocalizationHelper.shared.formatInteger(displayVolume))")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .contentTransition(.numericText())

                    Text(unitsManager.weightUnitString())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PastelTheme.textSecondary)
                }
            }

            Spacer()

            // 3. Finish Button (Warm Oat Capsule) or Sets Progress
            if workout.isActive {
                if let onFinish = onFinish {
                    Button(action: onFinish) {
                        Text("Finish")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(PastelTheme.textOnOat)
                            .padding(.horizontal, 18)
                            .frame(height: 38)
                            .background(PastelTheme.pastelOat)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.3), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Sets")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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



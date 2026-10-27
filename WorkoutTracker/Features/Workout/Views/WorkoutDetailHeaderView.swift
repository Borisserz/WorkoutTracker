

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
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if workout.isActive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(PastelTheme.pastelEmerald)
                                .frame(width: 8, height: 8)
                                .symbolEffect(.pulse)
                            Text(LocalizedStringKey("Live Workout"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(PastelTheme.pastelEmerald)
                        }
                        WorkoutTimerView(startDate: workout.date)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "flag.checkered").foregroundColor(PastelTheme.pastelOat)
                            Text(LocalizedStringKey("Completed"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(PastelTheme.pastelOat)
                        }
                        Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.title3)
                            .fontWeight(.heavy)
                            .foregroundColor(PastelTheme.textPrimary)
                    }
                }
                Spacer()

                ZStack {
                    Circle()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 48, height: 48)
                    Image(systemName: workout.isActive ? "bolt.fill" : "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundColor(workout.isActive ? PastelTheme.pastelAmber : PastelTheme.pastelEmerald)
                }
            }

            Divider().background(PastelTheme.cardBorder)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 11))
                            .foregroundColor(PastelTheme.textSecondary)
                        Text(LocalizedStringKey("Total Lifted"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(PastelTheme.textSecondary)
                            .textCase(.uppercase)
                    }

                    let volume = viewModel.workoutAnalytics.volume
                    let convertedVolume = unitsManager.convertFromKilograms(volume)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(LocalizationHelper.shared.formatInteger(convertedVolume))")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(PastelTheme.textPrimary)
                            .contentTransition(.numericText())
                        Text(unitsManager.weightUnitString())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(PastelTheme.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(PastelTheme.textSecondary)
                        Text(LocalizedStringKey("Completed Sets"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(PastelTheme.textSecondary)
                            .textCase(.uppercase)
                    }

                    Text("\(viewModel.workoutAnalytics.completedSetsCount)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(PastelTheme.textPrimary)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(20)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        .zIndex(10)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.workoutAnalytics.volume)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.workoutAnalytics.completedSetsCount)
        .animation(.easeInOut(duration: 0.8), value: workoutProgress)
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



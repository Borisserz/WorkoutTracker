

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

    private var gradientColors: [Color] {
        let pct = workoutProgress
        let startColor = Color.neonBlue.interpolate(to: Color.neonOrange, by: pct)
        let endColor = Color.neonPurple.interpolate(to: Color.neonRed, by: pct)
        return [startColor, endColor]
    }

    private var borderGradientColors: [Color] {
        let pct = workoutProgress
        let startColor = Color.neonBlue.interpolate(to: Color.neonOrange, by: pct).opacity(0.4)
        let endColor = Color.neonPurple.interpolate(to: Color.neonRed, by: pct).opacity(0.2)
        return [startColor, endColor]
    }

    private var iconBgGradientColors: [Color] {
        let pct = workoutProgress
        let startColor = Color.neonBlue.interpolate(to: Color.neonOrange, by: pct).opacity(0.15)
        let endColor = Color.neonPurple.interpolate(to: Color.neonRed, by: pct).opacity(0.15)
        return [startColor, endColor]
    }

    private var iconGradientColors: [Color] {
        let pct = workoutProgress
        let startColor = Color.neonBlue.interpolate(to: Color.neonOrange, by: pct)
        let endColor = Color.neonPurple.interpolate(to: Color.neonRed, by: pct)
        return [startColor, endColor]
    }

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
                            .foregroundColor(.white)
                    }
                }
                Spacer()

                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: iconBgGradientColors, startPoint: .top, endPoint: .bottom))
                        .frame(width: 50, height: 50)
                    Image(systemName: workout.isActive ? "bolt.fill" : "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(LinearGradient(colors: iconGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }

            Divider().background(Color.white.opacity(0.1))

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.current.secondaryText)
                        Text(LocalizedStringKey("Total Lifted"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.current.secondaryText)
                            .textCase(.uppercase)
                    }

                    let volume = viewModel.workoutAnalytics.volume
                    let convertedVolume = unitsManager.convertFromKilograms(volume)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(LocalizationHelper.shared.formatInteger(convertedVolume))")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        Text(unitsManager.weightUnitString())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.current.secondaryText)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.current.secondaryText)
                        Text(LocalizedStringKey("Completed Sets"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.current.secondaryText)
                            .textCase(.uppercase)
                    }

                    Text("\(viewModel.workoutAnalytics.completedSetsCount)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(Color.neonBlue.interpolate(to: Color.neonOrange, by: workoutProgress))
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(themeManager.current.surface)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: borderGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
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

extension Color {
    fileprivate func interpolate(to other: Color, by pct: Double) -> Color {
        let uiColor1 = UIColor(self)
        let uiColor2 = UIColor(other)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 + (r2 - r1) * CGFloat(pct)
        let g = g1 + (g2 - g1) * CGFloat(pct)
        let b = b1 + (b2 - b1) * CGFloat(pct)
        let a = a1 + (a2 - a1) * CGFloat(pct)
        
        return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}

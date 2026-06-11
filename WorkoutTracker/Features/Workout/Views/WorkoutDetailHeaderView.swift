

internal import SwiftUI

struct WorkoutDetailHeaderView: View {
    @Bindable var workout: Workout
    var viewModel: WorkoutDetailViewModel

    @Environment(UnitsManager.self) var unitsManager
    @Environment(ThemeManager.self) private var themeManager

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
                        .fill(LinearGradient(colors: [.cyan.opacity(0.15), .blue.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 50, height: 50)
                    Image(systemName: workout.isActive ? "bolt.fill" : "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                        .foregroundColor(.cyan)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(20)
        .background(themeManager.current.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .zIndex(10)
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

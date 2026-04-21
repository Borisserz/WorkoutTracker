

internal import SwiftUI

struct SessionSummaryGrid: View {
    @Bindable var workout: Workout
    var viewModel: WorkoutDetailViewModel
    @Environment(UnitsManager.self) var unitsManager

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {

            let volume = unitsManager.convertFromKilograms(viewModel.workoutAnalytics.volume)
            SummaryGlassCard(
                title: "Total Volume",
                value: "\(LocalizationHelper.shared.formatInteger(volume))",
                unit: unitsManager.weightUnitString(),
                icon: "scalemass.fill",
                colors: [.cyan, .blue]
            )

            SummaryGlassCard(
                title: "Sets Done",
                value: "\(viewModel.workoutAnalytics.completedSetsCount)",
                unit: "sets",
                icon: "checkmark.circle.fill",
                colors: [.green, .mint]
            )

            SummaryGlassCard(
                title: "Avg Effort",
                value: "\(workout.effortPercentage)",
                unit: "%",
                icon: "flame.fill",
                colors: [.orange, .red]
            )

            if workout.isActive {
                SummaryTimerGlassCard(
                    title: "Duration",
                    startDate: workout.date,
                    icon: "stopwatch.fill",
                    colors: [.purple, .indigo]
                )
            } else {
                SummaryGlassCard(
                    title: "Duration",
                    value: "\(workout.durationSeconds / 60)",
                    unit: "min",
                    icon: "stopwatch.fill",
                    colors: [.purple, .indigo]
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.workoutAnalytics.volume)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.workoutAnalytics.completedSetsCount)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: workout.effortPercentage)
    }
}

struct SummaryGlassCard: View {
    let title: LocalizedStringKey
    let value: String
    let unit: String
    let icon: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                        .opacity(0.2)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct SummaryTimerGlassCard: View {
    let title: LocalizedStringKey
    let startDate: Date
    let icon: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                        .opacity(0.2)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                Spacer()
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .symbolEffect(.pulse)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(startDate, style: .timer)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()

                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

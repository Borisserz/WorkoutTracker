internal import SwiftUI

struct SessionSummaryGrid: View {
    @Bindable var workout: Workout
    var viewModel: WorkoutDetailViewModel
    @Environment(UnitsManager.self) var unitsManager

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {

            let volume = unitsManager.convertFromKilograms(viewModel.workoutAnalytics.volume)
            SummaryMetricCard(
                title: "Total Volume",
                value: "\(LocalizationHelper.shared.formatInteger(volume))",
                unit: unitsManager.weightUnitString(),
                icon: "scalemass.fill",
                accentColor: PastelTheme.pastelOat
            )

            SummaryMetricCard(
                title: "Sets Done",
                value: "\(viewModel.workoutAnalytics.completedSetsCount)",
                unit: "sets",
                icon: "checkmark.circle.fill",
                accentColor: PastelTheme.pastelEmerald
            )

            SummaryMetricCard(
                title: "Avg Effort",
                value: "\(workout.effortPercentage)",
                unit: "%",
                icon: "flame.fill",
                accentColor: PastelTheme.pastelAmber
            )

            if workout.isActive {
                SummaryTimerMetricCard(
                    title: "Duration",
                    startDate: workout.date,
                    icon: "stopwatch.fill",
                    accentColor: PastelTheme.pastelLavender
                )
            } else {
                SummaryMetricCard(
                    title: "Duration",
                    value: "\(workout.durationSeconds / 60)",
                    unit: "min",
                    icon: "stopwatch.fill",
                    accentColor: PastelTheme.pastelLavender
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.workoutAnalytics.volume)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.workoutAnalytics.completedSetsCount)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: workout.effortPercentage)
    }
}

struct SummaryMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let unit: String
    let icon: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(accentColor)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(PastelTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(PastelTheme.textSecondary)
                }
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(PastelTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

struct SummaryTimerMetricCard: View {
    let title: LocalizedStringKey
    let startDate: Date
    let icon: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(accentColor)
                }
                Spacer()
                Circle()
                    .fill(PastelTheme.pastelEmerald)
                    .frame(width: 8, height: 8)
                    .symbolEffect(.pulse)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(startDate, style: .timer)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(PastelTheme.textPrimary)
                    .monospacedDigit()

                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(PastelTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

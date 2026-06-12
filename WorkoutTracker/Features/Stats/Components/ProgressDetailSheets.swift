internal import SwiftUI
import Charts

struct CurrentStreakDetailSheet: View {
    let streak: Int
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 40) {
                        Spacer().frame(height: 20)

                        StreakFireHeader(streak: streak)

                        StreakVisualizer(streak: streak)

                        StreakMotivationCard()
                    }
                }
            }
            .navigationTitle("Current Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

fileprivate struct StreakFireHeader: View {
    let streak: Int

    var body: some View {
        VStack(spacing: 40) {
            // Big Fire Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange.opacity(0.3), .red.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 160, height: 160)
                    .shadow(color: .orange.opacity(0.5), radius: 30, x: 0, y: 10)

                Image(systemName: "flame.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
            }
            
            // Main Text
            VStack(spacing: 8) {
                Text("\(streak) Day Streak")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                
                Text(streak > 0 ? "You're on fire! Keep the momentum going." : "Start your journey today by completing a workout.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

fileprivate struct StreakVisualizer: View {
    let streak: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Last 7 Days"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)

            HStack(spacing: 12) {
                ForEach(0..<7) { index in
                    let isActive = streak > (6 - index)
                    StreakVisualizerCircle(isActive: isActive)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
    }
}

fileprivate struct StreakVisualizerCircle: View {
    let isActive: Bool
    
    var body: some View {
        if isActive {
            Circle()
                .fill(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay(
                    Circle()
                        .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 0)
        } else {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay(
                    Circle()
                        .stroke(Color.clear, lineWidth: 2)
                )
                .shadow(color: .clear, radius: 8, x: 0, y: 0)
        }
    }
}

fileprivate struct StreakMotivationCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("How streaks work")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            
            Text("Your streak increases for every consecutive day you log a completed workout. Miss a day, and the fire goes out!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.white)
        )
        .padding(.horizontal, 24)
    }
}

struct WeeklyActivityDetailSheet: View {
    let stats: PeriodStats
    let chartData: [ChartDataPoint]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 10)

                        WeeklyActivityChartSection(chartData: chartData)

                        WeeklyActivityBentoGrid(stats: stats)
                    }
                }
            }
            .navigationTitle("Weekly Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

fileprivate struct WeeklyActivityChartSection: View {
    let chartData: [ChartDataPoint]
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Activity Volume"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)

            let unitStr = unitsManager.weightUnitString()
            
            Chart {
                ForEach(chartData) { item in
                    let displayVal = unitsManager.convertFromKilograms(item.value)
                    BarMark(
                        x: .value("Day", item.label),
                        y: .value("Volume", displayVal)
                    )
                    .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .bottom, endPoint: .top))
                    .cornerRadius(8)
                    .annotation(position: .top) {
                        if displayVal > 0 {
                            Text(LocalizationHelper.shared.formatFlexible(displayVal))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel() {
                        if let intVal = value.as(Double.self) {
                            Text("\(LocalizationHelper.shared.formatFlexible(intVal)) \(unitStr)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

fileprivate struct WeeklyActivityBentoGrid: View {
    let stats: PeriodStats
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Weekly Summary"))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                // Left column: Workouts & Time
                VStack(spacing: 16) {
                    BentoCard(
                        title: "Workouts",
                        value: "\(stats.workoutCount)",
                        icon: "figure.run",
                        colors: [.purple, .indigo]
                    )
                    BentoCard(
                        title: "Time",
                        value: "\(stats.totalDuration)m",
                        icon: "timer",
                        colors: [.green, .mint]
                    )
                }
                
                // Right column: Volume/Reps (Taller card)
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey("Total Reps"))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text("\(stats.totalReps)")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

fileprivate struct BentoCard: View {
    let title: String
    let value: String
    let icon: String
    let colors: [Color]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.white)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [colors[0].opacity(0.2), colors[1].opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

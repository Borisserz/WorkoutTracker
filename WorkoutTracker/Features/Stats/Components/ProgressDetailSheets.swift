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
            .navigationTitle("Текущий стрик")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

fileprivate struct StreakFireHeader: View {
    let streak: Int
    @State private var isPulsing = false
    @State private var glowIntensity: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 40) {
            // Big Fire Icon with pulsing animation
            ZStack {
                // Outer glow ring (animates)
                Circle()
                    .fill(RadialGradient(
                        colors: [PastelTheme.pastelAmber.opacity(glowIntensity * 0.5), .clear],
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    ))
                    .frame(width: 200, height: 200)
                    .scaleEffect(isPulsing ? 1.12 : 0.92)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulsing)

                // Inner circle background
                Circle()
                    .fill(PastelTheme.cardSurfaceSubtle)
                    .frame(width: 160, height: 160)
                    .overlay(
                        Circle().stroke(PastelTheme.cardBorder, lineWidth: 1)
                    )
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulsing)

                // Flame icon
                Image(systemName: "flame.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(PastelTheme.pastelAmber)
                    .scaleEffect(isPulsing ? 1.08 : 0.96)
                    .shadow(color: PastelTheme.pastelAmber.opacity(0.4), radius: isPulsing ? 16 : 6, x: 0, y: 0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            }
            .onAppear {
                isPulsing = true
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.85
                }
            }
            
            // Main Text
            VStack(spacing: 8) {
                Text("\(streak) дн. стрик")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(PastelTheme.pastelAmber)
                
                Text(streak > 0 ? "Отличный темп! Продолжайте в том же духе." : "Начните серию сегодня, завершив тренировку.")
                    .font(.body)
                    .foregroundColor(PastelTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

fileprivate struct StreakVisualizer: View {
    let streak: Int
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Последние 7 дней")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)

            HStack(spacing: 12) {
                ForEach(0..<7) { index in
                    let isActive = streak > index
                    StreakVisualizerCircle(isActive: isActive, index: index, appeared: appeared)
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
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }
}

fileprivate struct StreakVisualizerCircle: View {
    let isActive: Bool
    let index: Int
    let appeared: Bool

    // Red (index 0) → orange → yellow → green → teal → blue (index 6)
    private var gradientColors: [Color] {
        let palette: [[Color]] = [
            [Color(red: 1.0, green: 0.2, blue: 0.1), Color(red: 0.9, green: 0.1, blue: 0.0)],  // 0: deep red
            [Color(red: 1.0, green: 0.45, blue: 0.0), Color(red: 0.95, green: 0.25, blue: 0.0)], // 1: orange-red
            [Color(red: 1.0, green: 0.65, blue: 0.0), Color(red: 1.0, green: 0.45, blue: 0.0)],  // 2: orange
            [Color(red: 0.95, green: 0.85, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)],  // 3: yellow
            [Color(red: 0.2, green: 0.85, blue: 0.4), Color(red: 0.0, green: 0.65, blue: 0.3)],  // 4: green
            [Color(red: 0.0, green: 0.75, blue: 0.85), Color(red: 0.0, green: 0.55, blue: 0.75)], // 5: teal
            [Color(red: 0.15, green: 0.45, blue: 1.0), Color(red: 0.05, green: 0.2, blue: 0.9)],  // 6: blue
        ]
        return palette[min(index, palette.count - 1)]
    }

    private var glowColor: Color {
        gradientColors.first ?? .orange
    }

    private var strokeColor: Color {
        gradientColors.first?.opacity(0.6) ?? .orange.opacity(0.6)
    }

    var body: some View {
        Group {
            if isActive {
                Circle()
                    .fill(LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom))
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: 2)
                    )
                    .shadow(color: glowColor.opacity(0.55), radius: 10, x: 0, y: 0)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Circle()
                            .stroke(Color.clear, lineWidth: 2)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .scaleEffect(appeared ? 1.0 : 0.3)
        .opacity(appeared ? 1.0 : 0.0)
        .animation(
            .spring(response: 0.45, dampingFraction: 0.65)
                .delay(Double(index) * 0.06),
            value: appeared
        )
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
                    .foregroundStyle(LinearGradient(colors: [PastelTheme.pastelSage, PastelTheme.pastelSage.opacity(0.6)], startPoint: .top, endPoint: .bottom))
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
                .fill(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

fileprivate struct WeeklyActivityBentoGrid: View {
    let stats: PeriodStats
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Итоги недели")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                // Left column: Workouts & Time
                VStack(spacing: 16) {
                    BentoCard(
                        title: "Тренировки",
                        value: "\(stats.workoutCount)",
                        icon: "figure.run",
                        colors: [PastelTheme.pastelSlate, PastelTheme.pastelSlate.opacity(0.7)]
                    )
                    BentoCard(
                        title: "Время",
                        value: "\(stats.totalDuration) мин",
                        icon: "timer",
                        colors: [PastelTheme.pastelAmber, PastelTheme.pastelAmber.opacity(0.7)]
                    )
                }
                
                // Right column: Volume/Reps (Taller card)
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(PastelTheme.cardSurfaceSubtle)
                                    .frame(width: 48, height: 48)
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(PastelTheme.pastelLavender)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Всего повторений")
                                    .font(.subheadline)
                                    .foregroundColor(PastelTheme.textSecondary)
                                
                                Text("\(stats.totalReps)")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(PastelTheme.cardBorder, lineWidth: 1)
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
                .fill(colorScheme == .dark ? PastelTheme.cardSurface : Color.white)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(PastelTheme.cardSurfaceSubtle)
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(colors[0])
                    }
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(PastelTheme.textSecondary)
                    
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? PastelTheme.textPrimary : .black)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

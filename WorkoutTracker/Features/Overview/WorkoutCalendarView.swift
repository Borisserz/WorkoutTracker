internal import SwiftUI
import SwiftData

/// Lightweight transfer model representing a completed workout on the calendar.
struct MiniWorkout: Sendable, Identifiable {
    let id: PersistentIdentifier
    let date: Date
    let name: String
    let durationSeconds: Int
    let volumeKg: Double
    let exercisesCount: Int
}

/// Architectural Activity & Streak Calendar designed according to Apple Fitness+ HUD philosophy.
/// Presents a comprehensive timeline of workouts paved with mechanical day pressure plates,
/// highlighting streaks, total tonnage, and day telemetry with glowing sage dots.
struct WorkoutCalendarView: View {
    enum TimeRange: String, CaseIterable, Identifiable {
        case month = "Месяц"
        case threeMonths = "3 месяца"
        case year = "Год"
        case all = "Все время"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            case .all: return Int.max
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(ThemeManager.self) private var themeManager
    @Environment(UnitsManager.self) private var unitsManager
    @Environment(DashboardViewModel.self) private var dashboardViewModel
    @Environment(DIContainer.self) private var di
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTimeRange: TimeRange = .month
    @State private var allMiniWorkouts: [MiniWorkout] = []
    @State private var workoutsByMonth: [Int: [MiniWorkout]] = [:]
    @State private var workoutsByDay: [String: [MiniWorkout]] = [:]
    @State private var oldestWorkoutDate: Date? = nil
    @State private var isLoaded: Bool = false
    @State private var selectedDate: Date? = nil
    @State private var streakCount: Int = 0

    private var filteredWorkouts: [MiniWorkout] {
        let cutoff: Date
        if selectedTimeRange == .all {
            cutoff = Date.distantPast
        } else {
            cutoff = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        }
        return allMiniWorkouts.filter { $0.date >= cutoff }
    }

    private var totalTonnageFormatted: String {
        let total = filteredWorkouts.reduce(0.0) { $0 + $1.volumeKg }
        return "\(unitsManager.formatWeight(total)) \(unitsManager.weightUnitString())"
    }

    private var totalDurationFormatted: String {
        let totalSeconds = filteredWorkouts.reduce(0) { $0 + $1.durationSeconds }
        let hours = Double(totalSeconds) / 3600.0
        return String(format: "%.1f ч", hours)
    }

    private var monthsToDisplay: [Date] {
        let calendar = Calendar.current
        let today = Date()

        guard let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return []
        }

        let monthsToShow: Int
        switch selectedTimeRange {
        case .month:
            monthsToShow = 1
        case .threeMonths:
            monthsToShow = 3
        case .year:
            monthsToShow = 12
        case .all:
            if let oldest = oldestWorkoutDate {
                let components = calendar.dateComponents([.month], from: oldest, to: today)
                monthsToShow = max(1, (components.month ?? 0) + 1)
            } else {
                monthsToShow = 1
            }
        }

        var months: [Date] = []
        for i in 0..<monthsToShow {
            if let date = calendar.date(byAdding: .month, value: -i, to: startOfCurrentMonth) {
                months.append(date)
            }
        }
        return months
    }

    var body: some View {
        ZStack {
            // Background Canvas & Ambient Atmosphere
            PastelTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. Streak & Consistency Telemetry Header
                        streakTelemetryCard

                        // 2. Metrics Ribbon
                        metricsRibbon

                        // 3. Time Range Filter Capsules
                        timeRangeFilterPills

                        // 4. Months List with Pressure Plates Grid
                        if isLoaded {
                            monthsSection
                        } else {
                            VStack {
                                Spacer(minLength: 40)
                                ProgressView()
                                    .tint(PastelTheme.pastelOat)
                                Spacer(minLength: 40)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // 5. Selected Day Workout Inspection Drawer
                if let date = selectedDate, let dayWorkouts = workoutsByDay[dayKey(for: date)], !dayWorkouts.isEmpty {
                    selectedDayDrawer(for: date, workouts: dayWorkouts)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Календарь активности")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PastelTheme.textTertiary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadCalendarData()
        }
    }

    // MARK: - Streak & Consistency Header Card
    private var streakTelemetryCard: some View {
        HStack(spacing: 14) {
            // Animated Streak Flame Crest
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PastelTheme.cardSurfaceSubtle)
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PastelTheme.pastelAmber.opacity(0.35), lineWidth: 1)
                    )

                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(PastelTheme.pastelAmber)
                    .shadow(color: PastelTheme.pastelAmber.opacity(0.5), radius: 6)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(streakCount) дн.")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .monospacedDigit()

                    Text("серия тренировок")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(PastelTheme.pastelAmber)
                }

                Text(streakCount > 0 ? "Ударный ритм! Продолжайте отмечать дни тренировок" : "Начните тренировку сегодня, чтобы зажечь серию")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PastelTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Metrics Ribbon
    private var metricsRibbon: some View {
        HStack(spacing: 10) {
            metricItem(title: "Тренировки", value: "\(filteredWorkouts.count)", accent: PastelTheme.pastelOat)
            metricItem(title: "Тоннаж", value: totalTonnageFormatted, accent: PastelTheme.pastelSage)
            metricItem(title: "Время", value: totalDurationFormatted, accent: PastelTheme.pastelSlate)
        }
    }

    private func metricItem(title: String, value: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(PastelTheme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(PastelTheme.cardSurfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Time Range Filter Pills
    private var timeRangeFilterPills: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases) { range in
                let isSelected = selectedTimeRange == range
                Button {
                    HapticManager.playSelection()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selectedTimeRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? PastelTheme.textOnOat : PastelTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: PastelTheme.ButtonMetrics.pillHeight)
                        .background(isSelected ? PastelTheme.pastelOat : PastelTheme.cardSurface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(isSelected ? PastelTheme.pastelOat : PastelTheme.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Months Section
    private var monthsSection: some View {
        VStack(spacing: 20) {
            ForEach(monthsToDisplay, id: \.self) { monthDate in
                let comps = Calendar.current.dateComponents([.year, .month], from: monthDate)
                let key = (comps.year! * 100) + comps.month!
                let monthWorkouts = workoutsByMonth[key] ?? []

                ArchitecturalMonthView(
                    monthDate: monthDate,
                    monthWorkouts: monthWorkouts,
                    workoutsByDay: workoutsByDay,
                    selectedDate: $selectedDate
                )
            }
        }
    }

    // MARK: - Selected Day Drawer
    private func selectedDayDrawer(for date: Date, workouts: [MiniWorkout]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(PastelTheme.pastelSage).frame(width: 7, height: 7)
                    Text(date.formatted(.dateTime.weekday(.wide).day().month()))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDate = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PastelTheme.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(Circle())
                }
            }

            ForEach(workouts) { workout in
                miniWorkoutRow(workout: workout)
            }
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.pastelSage.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 14, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func miniWorkoutRow(workout: MiniWorkout) -> some View {
        NavigationLink(destination: workoutDetailDestination(for: workout)) {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PastelTheme.pastelSage)
                    .frame(width: 36, height: 36)
                    .background(PastelTheme.cardSurfaceSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    let formattedWeight = unitsManager.formatWeight(workout.volumeKg)
                    Text("\(workout.durationSeconds / 60) мин · \(formattedWeight) \(unitsManager.weightUnitString())")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PastelTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PastelTheme.textTertiary)
            }
            .padding(10)
            .background(PastelTheme.cardSurfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PastelTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func workoutDetailDestination(for mw: MiniWorkout) -> some View {
        if let workout = context.model(for: mw.id) as? Workout {
            WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
        } else {
            Text("Детали тренировки недоступны")
        }
    }

    private func dayKey(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }

    private func loadCalendarData() {
        let container = context.container

        Task.detached(priority: .userInitiated) {
            let bgContext = ModelContext(container)
            let desc = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let allWorkouts = (try? bgContext.fetch(desc)) ?? []

            let miniWorkouts = allWorkouts.map { w in
                MiniWorkout(
                    id: w.persistentModelID,
                    date: w.date,
                    name: w.title.isEmpty ? "Тренировка" : w.title,
                    durationSeconds: w.durationSeconds,
                    volumeKg: w.totalStrengthVolume,
                    exercisesCount: w.exercises.count
                )
            }
            let oldest = miniWorkouts.min(by: { $0.date < $1.date })?.date

            var monthDict: [Int: [MiniWorkout]] = [:]
            var dayDict: [String: [MiniWorkout]] = [:]
            let calendar = Calendar.current

            for mw in miniWorkouts {
                let comps = calendar.dateComponents([.year, .month, .day], from: mw.date)
                if let y = comps.year, let m = comps.month {
                    let key = (y * 100) + m
                    monthDict[key, default: []].append(mw)
                }
                if let y = comps.year, let m = comps.month, let d = comps.day {
                    let dKey = "\(y)-\(m)-\(d)"
                    dayDict[dKey, default: []].append(mw)
                }
            }

            // Calculate active streak count
            let streak = Self.calculateStreak(from: miniWorkouts)

            await MainActor.run {
                self.allMiniWorkouts = miniWorkouts
                self.workoutsByMonth = monthDict
                self.workoutsByDay = dayDict
                self.oldestWorkoutDate = oldest
                self.streakCount = streak
                self.isLoaded = true
            }
        }
    }

    private static func calculateStreak(from workouts: [MiniWorkout]) -> Int {
        guard !workouts.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var currentDay = today

        // Check if user worked out today
        let workedOutToday = workouts.contains { calendar.isDate($0.date, inSameDayAs: today) }
        if !workedOutToday {
            // Check yesterday
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            let workedOutYesterday = workouts.contains { calendar.isDate($0.date, inSameDayAs: yesterday) }
            if !workedOutYesterday { return 0 }
            currentDay = yesterday
        }

        var streak = 0
        while true {
            let targetDay = currentDay
            let hasWorkout = workouts.contains { calendar.isDate($0.date, inSameDayAs: targetDay) }
            if hasWorkout {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
                currentDay = previousDay
            } else {
                break
            }
        }
        return streak
    }
}

/// Architectural month container containing the 7-column grid of mechanical day plates.
private struct ArchitecturalMonthView: View {
    let monthDate: Date
    let monthWorkouts: [MiniWorkout]
    let workoutsByDay: [String: [MiniWorkout]]
    @Binding var selectedDate: Date?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: monthDate).uppercased()
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))
        else { return [] }

        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }

    private var firstDayOffset: Int {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        let weekday = calendar.component(.weekday, from: startOfMonth)
        // Russian week starts on Monday (weekday 2 in gregorian)
        let firstWeekdaySystem = 2
        return (weekday - firstWeekdaySystem + 7) % 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Month Title & Mini Stats
            HStack {
                Text(monthTitle)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)

                Spacer()

                if !monthWorkouts.isEmpty {
                    Text("\(monthWorkouts.count) трен.")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.pastelSage)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PastelTheme.cardSurfaceSubtle)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PastelTheme.pastelSage.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, 4)

            // Weekday Strip: ПН, ВТ, СР, ЧТ, ПТ, СБ, ВС
            HStack(spacing: 6) {
                ForEach(["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"], id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 7-Column Day Pressure Plates Grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<firstDayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 52)
                }

                ForEach(daysInMonth, id: \.self) { date in
                    let dKey = dayKey(for: date)
                    let dayWorkouts = workoutsByDay[dKey] ?? []
                    let isSelected = selectedDate != nil && calendar.isDate(selectedDate!, inSameDayAs: date)

                    CalendarDayPressurePlate(
                        date: date,
                        hasWorkout: !dayWorkouts.isEmpty,
                        workoutCount: dayWorkouts.count,
                        isSelected: isSelected,
                        onTap: {
                            HapticManager.playSelection()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                                if isSelected {
                                    selectedDate = nil
                                } else {
                                    selectedDate = date
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    private func dayKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }
}

/// Architectural day pressure plate for the calendar grid.
/// Features bevel specular highlights, physical spring depression,
/// and clear distinction: days with workouts have glowing sage dots,
/// days without have NO dots.
private struct CalendarDayPressurePlate: View {
    let date: Date
    let hasWorkout: Bool
    let workoutCount: Int
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isDepressed: Bool = false

    private var calendar: Calendar { Calendar.current }
    private var dayNumber: String { "\(calendar.component(.day, from: date))" }
    private var isToday: Bool { calendar.isDateInToday(date) }

    var body: some View {
        Button {
            isDepressed = true
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                isDepressed = false
                onTap()
            }
        } label: {
            ZStack {
                // Slab Surface Background with Bevel Highlights
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isSelected
                            ? PastelTheme.cardSurfaceSubtle
                            : (hasWorkout ? PastelTheme.cardSurface : PastelTheme.cardSurfaceSubtle.opacity(0.65))
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDepressed ? 0.02 : (hasWorkout ? 0.12 : 0.04)),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    )

                // 4 Micro Corner Screws
                cornerScrews

                // Plate Content: Day number + Glowing dot
                VStack(spacing: 2) {
                    Spacer(minLength: 1)

                    Text(dayNumber)
                        .font(.system(size: 13, weight: (isToday || hasWorkout) ? .bold : .medium, design: .rounded))
                        .foregroundStyle(
                            isSelected
                                ? PastelTheme.pastelOat
                                : (hasWorkout
                                    ? PastelTheme.textPrimary
                                    : (isToday ? PastelTheme.pastelOat : PastelTheme.textTertiary.opacity(0.85)))
                        )
                        .monospacedDigit()

                    // Bottom Indicator: Glowing dot ONLY for workout days, completely empty for rest days!
                    if hasWorkout {
                        Circle()
                            .fill(PastelTheme.pastelSage)
                            .frame(width: 5, height: 5)
                            .shadow(color: PastelTheme.pastelSage.opacity(0.7), radius: 3)
                    } else {
                        Color.clear
                            .frame(width: 5, height: 5)
                    }

                    Spacer(minLength: 1)
                }
                .padding(.vertical, 2)
            }
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        isSelected
                            ? PastelTheme.pastelOat
                            : (isToday
                                ? PastelTheme.pastelOat.opacity(0.85)
                                : (hasWorkout ? PastelTheme.pastelSage.opacity(0.4) : PastelTheme.cardBorder.opacity(0.3))),
                        lineWidth: isSelected ? 1.5 : (isToday ? 1.2 : 0.8)
                    )
            )
            .shadow(
                color: hasWorkout ? PastelTheme.pastelSage.opacity(0.2) : Color.black.opacity(0.15),
                radius: isDepressed ? 1 : (isSelected ? 6 : 3),
                y: isDepressed ? 0.5 : 2
            )
            .offset(y: isDepressed ? 2.5 : 0)
            .scaleEffect(isDepressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isDepressed)
        }
        .buttonStyle(.plain)
    }

    private var cornerScrews: some View {
        VStack {
            HStack {
                Circle().fill(PastelTheme.cardBorder.opacity(0.28)).frame(width: 2, height: 2)
                Spacer()
                Circle().fill(PastelTheme.cardBorder.opacity(0.28)).frame(width: 2, height: 2)
            }
            Spacer()
            HStack {
                Circle().fill(PastelTheme.cardBorder.opacity(0.28)).frame(width: 2, height: 2)
                Spacer()
                Circle().fill(PastelTheme.cardBorder.opacity(0.28)).frame(width: 2, height: 2)
            }
        }
        .padding(3.5)
    }
}

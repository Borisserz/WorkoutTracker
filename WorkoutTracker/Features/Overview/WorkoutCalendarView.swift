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
    let muscleGroups: [String]
    let totalSets: Int
}

/// Data payload for inspecting a selected calendar day in the popover sheet.
struct InspectedDayData: Identifiable {
    var id: String { dateKey }
    let date: Date
    let dateKey: String
    let workouts: [MiniWorkout]
    let streakAtDay: Int
}

/// Architectural Activity & Streak Calendar designed according to Apple Fitness+ HUD philosophy.
/// Presents a comprehensive timeline of workouts paved with mechanical day pressure plates,
/// highlighting fiery streaks (>5 days), steady streaks (1-4 days), rest days,
/// and rich interactive day inspection sheets.
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

    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]
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
    @State private var streaksByDay: [String: Int] = [:]
    @State private var oldestWorkoutDate: Date? = nil
    @State private var isLoaded: Bool = true
    @State private var selectedDate: Date? = nil
    @State private var streakCount: Int = 0
    @State private var inspectedDay: InspectedDayData? = nil

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
            // Background Canvas
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

                            // 5. Calendar Activity Legend (Below Month Grid)
                            calendarLegendSection
                                .padding(.top, 4)
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
        .onChange(of: allWorkouts.count) { _, _ in
            loadCalendarData()
        }
        .sheet(item: $inspectedDay) { data in
            DayInspectionSheet(
                data: data,
                context: context,
                unitsManager: unitsManager,
                di: di
            )
            .presentationDetents([.fraction(data.workouts.isEmpty ? 0.38 : 0.60), .large])
            .presentationDragIndicator(.visible)
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
                            .stroke(
                                streakCount >= 5
                                    ? PastelTheme.pastelAmber.opacity(0.6)
                                    : PastelTheme.cardBorder,
                                lineWidth: 1.2
                            )
                    )

                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        streakCount >= 5
                            ? PastelTheme.pastelAmber
                            : (streakCount > 0 ? PastelTheme.pastelAmber.opacity(0.85) : PastelTheme.textTertiary)
                    )
                    .shadow(
                        color: streakCount >= 5 ? PastelTheme.pastelAmber.opacity(0.6) : .clear,
                        radius: 8
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(streakCount) дн.")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)
                        .monospacedDigit()

                    if streakCount >= 5 {
                        HStack(spacing: 4) {
                            Circle().fill(PastelTheme.pastelAmber).frame(width: 5, height: 5)
                            Text("В ОГНЕ")
                                .font(.system(size: 9.5, weight: .black, design: .rounded))
                                .foregroundStyle(PastelTheme.pastelAmber)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(PastelTheme.pastelAmber.opacity(0.18))
                        .clipShape(Capsule())
                    } else {
                        Text("серия тренировок")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(PastelTheme.pastelAmber)
                    }
                }

                Text(streakCount >= 5
                     ? "Серия в огне! Непрерывный темп более 5 дней подряд"
                     : (streakCount > 0 ? "Ударный ритм! Продолжайте отмечать дни тренировок" : "Начните тренировку сегодня, чтобы зажечь серию"))
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
                .stroke(
                    streakCount >= 5
                        ? PastelTheme.pastelAmber.opacity(0.35)
                        : PastelTheme.cardBorder,
                    lineWidth: 1
                )
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
                    streaksByDay: streaksByDay,
                    selectedDate: $selectedDate,
                    onInspectDay: { dayDate in
                        let dKey = dayKey(for: dayDate)
                        let w = workoutsByDay[dKey] ?? []
                        let s = streaksByDay[dKey] ?? (w.isEmpty ? 0 : 1)
                        inspectedDay = InspectedDayData(
                            date: dayDate,
                            dateKey: dKey,
                            workouts: w,
                            streakAtDay: s
                        )
                    }
                )
            }
        }
    }

    // MARK: - Calendar Legend Section
    private var calendarLegendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Обозначения на сетке")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(PastelTheme.textSecondary)

            HStack(spacing: 8) {
                // 1. Flame: Streak > 5 days
                legendItem(
                    badge: AnyView(
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PastelTheme.pastelAmber)
                            .shadow(color: PastelTheme.pastelAmber.opacity(0.8), radius: 3)
                    ),
                    title: "Стрик 5+ дней",
                    subtitle: "Серия в огне"
                )

                // 2. Green Dot: Streak up to 5 days
                legendItem(
                    badge: AnyView(
                        Circle()
                            .fill(PastelTheme.pastelSage)
                            .frame(width: 7, height: 7)
                            .shadow(color: PastelTheme.pastelSage.opacity(0.8), radius: 3)
                    ),
                    title: "Стрик до 5 дней",
                    subtitle: "Тренировка"
                )

                // 3. Gray Square with subtle face: Rest day
                legendItem(
                    badge: AnyView(
                        ZStack {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(PastelTheme.cardSurfaceSubtle)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(PastelTheme.cardBorder.opacity(0.35), lineWidth: 0.8)
                                )

                            Image(systemName: "face.dashed")
                                .font(.system(size: 9))
                                .foregroundStyle(PastelTheme.textTertiary.opacity(0.8))
                        }
                    ),
                    title: "Без тренировки",
                    subtitle: "День отдыха"
                )
            }
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    private func legendItem(badge: AnyView, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(PastelTheme.cardSurfaceSubtle)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(PastelTheme.cardBorder, lineWidth: 0.8))

                badge
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PastelTheme.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(PastelTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayKey(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }

    private func loadCalendarData() {
        let miniWorkouts = allWorkouts.map { w in
            let slugs = w.exercises.map { $0.muscleGroup }
            let uniqueGroups = Array(Set(slugs.filter { !$0.isEmpty }))
            let setsCount = w.exercises.reduce(0) { $0 + $1.setsCount }
            return MiniWorkout(
                id: w.persistentModelID,
                date: w.date,
                name: w.title.isEmpty ? "Силовая тренировка" : w.title,
                durationSeconds: w.durationSeconds,
                volumeKg: w.totalStrengthVolume,
                exercisesCount: w.exercises.count,
                muscleGroups: uniqueGroups,
                totalSets: setsCount
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

        // Calculate per-day cumulative streak for all calendar dates
        let sortedDates = Array(Set(miniWorkouts.map { calendar.startOfDay(for: $0.date) })).sorted()
        var streakMap: [String: Int] = [:]
        var runningStreak = 0
        var lastWorkoutDate: Date? = nil

        for d in sortedDates {
            if let last = lastWorkoutDate {
                let diff = calendar.dateComponents([.day], from: last, to: d).day ?? 0
                if diff == 1 || diff == 2 {
                    runningStreak += 1
                } else {
                    runningStreak = 1
                }
            } else {
                runningStreak = 1
            }
            lastWorkoutDate = d

            let comps = calendar.dateComponents([.year, .month, .day], from: d)
            if let y = comps.year, let m = comps.month, let day = comps.day {
                streakMap["\(y)-\(m)-\(day)"] = runningStreak
            }
        }

        // Calculate active current streak count
        let streak = Self.calculateStreak(from: miniWorkouts)

        self.allMiniWorkouts = miniWorkouts
        self.workoutsByMonth = monthDict
        self.workoutsByDay = dayDict
        self.streaksByDay = streakMap
        self.oldestWorkoutDate = oldest
        self.streakCount = streak
        self.isLoaded = true
    }

    private static func calculateStreak(from workouts: [MiniWorkout]) -> Int {
        guard !workouts.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var currentDay = today

        let workedOutToday = workouts.contains { calendar.isDate($0.date, inSameDayAs: today) }
        if !workedOutToday {
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

// MARK: - Architectural Month Container View
private struct ArchitecturalMonthView: View {
    let monthDate: Date
    let monthWorkouts: [MiniWorkout]
    let workoutsByDay: [String: [MiniWorkout]]
    let streaksByDay: [String: Int]
    @Binding var selectedDate: Date?
    let onInspectDay: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: monthDate).capitalized
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
                    let streakAtDay = streaksByDay[dKey] ?? 0
                    let isSelected = selectedDate != nil && calendar.isDate(selectedDate!, inSameDayAs: date)

                    CalendarDayPressurePlate(
                        date: date,
                        hasWorkout: !dayWorkouts.isEmpty,
                        workoutCount: dayWorkouts.count,
                        streakAtDay: streakAtDay,
                        isSelected: isSelected,
                        onTap: {
                            selectedDate = date
                            onInspectDay(date)
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

// MARK: - Mechanical Day Pressure Plate
private struct CalendarDayPressurePlate: View {
    let date: Date
    let hasWorkout: Bool
    let workoutCount: Int
    let streakAtDay: Int
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
                // Background Plate
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isSelected
                            ? PastelTheme.cardSurfaceSubtle
                            : (hasWorkout
                                ? (streakAtDay >= 5 ? PastelTheme.cardSurface : PastelTheme.cardSurface)
                                : PastelTheme.cardSurfaceSubtle.opacity(0.65))
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDepressed ? 0.02 : (hasWorkout ? 0.10 : 0.03)),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    )

                // Micro Corner Screws
                cornerScrews

                // Plate Content: Day number + Streak / Rest Indicator
                VStack(spacing: 2) {
                    Spacer(minLength: 1)

                    Text(dayNumber)
                        .font(.system(size: 13, weight: (isToday || hasWorkout) ? .bold : .medium, design: .rounded))
                        .foregroundStyle(
                            isSelected
                                ? PastelTheme.pastelOat
                                : (hasWorkout
                                    ? PastelTheme.textPrimary
                                    : (isToday ? PastelTheme.pastelOat : PastelTheme.textTertiary.opacity(0.75)))
                        )
                        .monospacedDigit()

                    // Indicator:
                    // 1) Flame if streak >= 5
                    // 2) Sage dot if streak < 5
                    // 3) Subtle rest square with face.dashed if rest day
                    if hasWorkout {
                        if streakAtDay >= 5 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(PastelTheme.pastelAmber)
                                .shadow(color: PastelTheme.pastelAmber.opacity(0.85), radius: 3)
                        } else {
                            Circle()
                                .fill(PastelTheme.pastelSage)
                                .frame(width: 5, height: 5)
                                .shadow(color: PastelTheme.pastelSage.opacity(0.7), radius: 3)
                        }
                    } else {
                        // Muted resting face indicator in dark surface
                        ZStack {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(PastelTheme.cardBorder.opacity(0.2))
                                .frame(width: 9, height: 9)

                            Image(systemName: "face.dashed")
                                .font(.system(size: 7))
                                .foregroundStyle(PastelTheme.textTertiary.opacity(0.55))
                        }
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
                                : (hasWorkout
                                    ? (streakAtDay >= 5 ? PastelTheme.pastelAmber.opacity(0.55) : PastelTheme.pastelSage.opacity(0.4))
                                    : PastelTheme.cardBorder.opacity(0.25))),
                        lineWidth: isSelected ? 1.5 : (isToday ? 1.2 : 0.8)
                    )
            )
            .shadow(
                color: hasWorkout
                    ? (streakAtDay >= 5 ? PastelTheme.pastelAmber.opacity(0.25) : PastelTheme.pastelSage.opacity(0.18))
                    : Color.black.opacity(0.12),
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
                Circle().fill(PastelTheme.cardBorder.opacity(0.24)).frame(width: 2, height: 2)
                Spacer()
                Circle().fill(PastelTheme.cardBorder.opacity(0.24)).frame(width: 2, height: 2)
            }
            Spacer()
            HStack {
                Circle().fill(PastelTheme.cardBorder.opacity(0.24)).frame(width: 2, height: 2)
                Spacer()
                Circle().fill(PastelTheme.cardBorder.opacity(0.24)).frame(width: 2, height: 2)
            }
        }
        .padding(3.5)
    }
}

// MARK: - Interactive Day Inspection Sheet (Apple Fitness+ HUD)
struct DayInspectionSheet: View {
    let data: InspectedDayData
    let context: ModelContext
    let unitsManager: UnitsManager
    let di: DIContainer
    @Environment(\.dismiss) private var dismiss

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        let raw = formatter.string(from: data.date)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PastelTheme.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(formattedDate)
                                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                                    .foregroundStyle(PastelTheme.textPrimary)

                                if !data.workouts.isEmpty {
                                    if data.streakAtDay >= 5 {
                                        HStack(spacing: 5) {
                                            Image(systemName: "flame.fill")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(PastelTheme.pastelAmber)
                                            Text("Стрик: \(data.streakAtDay) дней подряд • В ОГНЕ")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(PastelTheme.pastelAmber)
                                        }
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 3.5)
                                        .background(PastelTheme.pastelAmber.opacity(0.18))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(PastelTheme.pastelAmber.opacity(0.4), lineWidth: 1))
                                    } else {
                                        HStack(spacing: 5) {
                                            Circle()
                                                .fill(PastelTheme.pastelSage)
                                                .frame(width: 6, height: 6)
                                            Text("День тренировки • Стрик: \(data.streakAtDay) дн.")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(PastelTheme.pastelSage)
                                        }
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 3.5)
                                        .background(PastelTheme.pastelSage.opacity(0.15))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(PastelTheme.pastelSage.opacity(0.35), lineWidth: 1))
                                    }
                                } else {
                                    HStack(spacing: 5) {
                                        Image(systemName: "moon.stars.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(PastelTheme.pastelSlate)
                                        Text("День отдыха и восстановления")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(PastelTheme.pastelSlate)
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3.5)
                                    .background(PastelTheme.pastelSlate.opacity(0.15))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(PastelTheme.pastelSlate.opacity(0.35), lineWidth: 1))
                                }
                            }

                            Spacer()

                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(PastelTheme.textTertiary, PastelTheme.cardSurfaceSubtle)
                            }
                        }
                        .padding(.top, 16)

                        // Body
                        if !data.workouts.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(data.workouts) { workout in
                                    workoutInspectionCard(workout: workout)
                                }
                            }
                        } else {
                            restDayInspectionCard
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Workout Card
    private func workoutInspectionCard(workout: MiniWorkout) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PastelTheme.pastelSage.opacity(0.35), lineWidth: 1)
                        )

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PastelTheme.pastelSage)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text(workout.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PastelTheme.textSecondary)
                }

                Spacer()
            }

            // 3 Key Metrics
            HStack(spacing: 8) {
                metricCell(
                    title: "Время",
                    value: "\(workout.durationSeconds / 60) мин",
                    icon: "clock.fill",
                    color: PastelTheme.pastelSlate
                )

                metricCell(
                    title: "Тоннаж",
                    value: "\(unitsManager.formatWeight(workout.volumeKg)) \(unitsManager.weightUnitString())",
                    icon: "scalemass.fill",
                    color: PastelTheme.pastelSage
                )

                metricCell(
                    title: "Нагрузка",
                    value: "\(workout.exercisesCount) упр. · \(workout.totalSets) с.",
                    icon: "flame.fill",
                    color: PastelTheme.pastelAmber
                )
            }

            // Targeted Muscles
            if !workout.muscleGroups.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Мышечные группы:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PastelTheme.textTertiary)

                    HStack(spacing: 6) {
                        ForEach(workout.muscleGroups.prefix(4), id: \.self) { group in
                            Text(MuscleDisplayHelper.getDisplayName(for: group))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(PastelTheme.textPrimary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(PastelTheme.cardSurfaceSubtle)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(PastelTheme.cardBorder, lineWidth: 1))
                        }
                    }
                }
            }

            // Direct link to detail
            if let w = context.model(for: workout.id) as? Workout {
                NavigationLink(destination: WorkoutDetailView(workout: w, viewModel: di.makeWorkoutDetailViewModel())) {
                    HStack {
                        Text("Подробный лог подходов")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(PastelTheme.textOnOat)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(PastelTheme.pastelOat)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }

    private func metricCell(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(PastelTheme.textTertiary)
            }

            Text(value)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(PastelTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(PastelTheme.cardSurfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Rest Day Card
    private var restDayInspectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PastelTheme.cardSurfaceSubtle)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PastelTheme.pastelSlate.opacity(0.35), lineWidth: 1)
                        )

                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PastelTheme.pastelSlate)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Мышцы восстанавливаются")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("Плановая суперкомпенсация")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PastelTheme.textSecondary)
                }

                Spacer()
            }

            Text("В этот день тренировки не было. Время отдыха необходимо волокнам для синтеза белка, восстановления гликогена и регенерации нервной системы перед новыми силовыми рекордами.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(PastelTheme.textSecondary)
                .lineSpacing(3)

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(PastelTheme.pastelLavender)

                Text("Совет: полноценный сон 7–8 часов и баланс белков с углеводами гарантируют ускоренный мышечный рост.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(PastelTheme.textTertiary)
                    .lineSpacing(2)
            }
            .padding(10)
            .background(PastelTheme.cardSurfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .background(PastelTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PastelTheme.cardBorder, lineWidth: 1)
        )
    }
}

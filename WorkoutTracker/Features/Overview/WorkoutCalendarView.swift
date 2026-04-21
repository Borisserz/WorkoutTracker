

internal import SwiftUI
import SwiftData

struct MiniWorkout: Sendable {
    let date: Date
    let id: PersistentIdentifier
}

struct WorkoutCalendarView: View {

    enum TimeRange: String, CaseIterable {
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
        case all = "All Time"

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
    @Environment(\.colorScheme) private var colorScheme 

    @State private var selectedTimeRange: TimeRange = .month
    @State private var totalWorkoutCount: Int = 0

    @State private var workoutsByMonth: [Int: [MiniWorkout]] = [:]
    @State private var allMiniWorkouts: [MiniWorkout] = []
    @State private var oldestWorkoutDate: Date? = nil
    @State private var isLoaded: Bool = false

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
        VStack(spacing: 0) {
            statsHeader
            Divider()

            if isLoaded {
                calendarList
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .background(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
        .navigationTitle(LocalizedStringKey("Calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCalendarData()
        }
    }

    private func loadCalendarData() {
        let container = context.container

        Task.detached(priority: .userInitiated) {
            let bgContext = ModelContext(container)
            let desc = FetchDescriptor<Workout>()
            let allWorkouts = (try? bgContext.fetch(desc)) ?? []

            let miniWorkouts = allWorkouts.map { MiniWorkout(date: $0.date, id: $0.persistentModelID) }
            let oldest = miniWorkouts.min(by: { $0.date < $1.date })?.date

            var dict: [Int: [MiniWorkout]] = [:]
            let calendar = Calendar.current

            for mw in miniWorkouts {
                let comps = calendar.dateComponents([.year, .month], from: mw.date)
                if let y = comps.year, let m = comps.month {
                    let key = (y * 100) + m
                    dict[key, default: []].append(mw)
                }
            }

            await MainActor.run {
                self.allMiniWorkouts = miniWorkouts
                self.workoutsByMonth = dict
                self.oldestWorkoutDate = oldest
                self.isLoaded = true
                self.updateWorkoutCount()
            }
        }
    }

    private func updateWorkoutCount() {
        let calendar = Calendar.current
        let cutoff: Date
        if selectedTimeRange == .all {
            cutoff = Date.distantPast
        } else {
            cutoff = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        }
        totalWorkoutCount = allMiniWorkouts.filter { $0.date >= cutoff }.count
    }

    private var statsHeader: some View {
        VStack(spacing: 10) {
            Picker(LocalizedStringKey("Time Range"), selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(LocalizedStringKey(range.rawValue)).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTimeRange) { _, _ in
                updateWorkoutCount()
            }

            HStack(alignment: .lastTextBaseline) {
                Text("\(totalWorkoutCount)")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text(LocalizedStringKey("workouts done"))
                    .font(.headline)
                    .foregroundColor(themeManager.current.secondaryText)
                    .padding(.bottom, 6)
            }
            .animation(.default, value: totalWorkoutCount)
        }
        .padding()
        .background(colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
    }

    private var calendarList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if allMiniWorkouts.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: LocalizedStringKey("No workouts yet"),
                        message: LocalizedStringKey("Start tracking your workouts to see them appear on the calendar. Each completed workout will be highlighted!")
                    )
                    .padding(.top, 50)
                } else {
                    VStack(spacing: 25) {
                        ForEach(monthsToDisplay.indices, id: \.self) { index in
                            let monthDate = monthsToDisplay[index]
                            let comps = Calendar.current.dateComponents([.year, .month], from: monthDate)
                            let key = (comps.year! * 100) + comps.month!
                            let monthWorkouts = workoutsByMonth[key] ?? []

                            MonthView(monthDate: monthDate, monthWorkouts: monthWorkouts)
                                .id(index)
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: selectedTimeRange) { _ in
                if !monthsToDisplay.isEmpty {
                    proxy.scrollTo(0, anchor: .top)
                }
            }
        }
    }
}

struct MonthView: View {
    let monthDate: Date
    let monthWorkouts: [MiniWorkout]
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var context
    @Environment(DIContainer.self) private var di
    @Environment(\.colorScheme) private var colorScheme 

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var monthTitle: String {
        monthDate.formatted(.dateTime.month(.wide).year())
    }

    var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))
        else { return [] }

        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }

    var firstDayOffset: Int {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let firstWeekdaySystem = calendar.firstWeekday
        return (weekday - firstWeekdaySystem + 7) % 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text(monthTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.current.primaryAccent)
                .textCase(.uppercase)
                .padding(.leading, 8)

            VStack(spacing: 16) {
                weekDaysHeader
                daysGrid
            }
        }
        .padding(20)

        .background(colorScheme == .dark ? themeManager.current.surface : Color.white)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.05), radius: 15, x: 0, y: 5)
    }

    private var weekDaysHeader: some View {
        HStack {
            ForEach(0..<7, id: \.self) { index in
                let daySymbolIndex = (calendar.firstWeekday - 1 + index) % 7
                Text(calendar.shortWeekdaySymbols[daySymbolIndex].prefix(1))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.current.secondaryAccent)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {

            ForEach(0..<firstDayOffset, id: \.self) { _ in
                Color.clear.frame(height: 44)
            }

            ForEach(daysInMonth, id: \.self) { date in
                dayView(for: date)
            }
        }
    }

    @ViewBuilder
    private func dayView(for date: Date) -> some View {
        if let mw = monthWorkouts.first(where: { calendar.isDate($0.date, inSameDayAs: date) }),
           let workout = context.model(for: mw.id) as? Workout {

            NavigationLink(destination: WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())) {
                DayCell(date: date, isWorkout: true)
            }
            .buttonStyle(PlainButtonStyle())

        } else {

            DayCell(date: date, isWorkout: false)
        }
    }
}

struct DayCell: View {
    let date: Date
    let isWorkout: Bool
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    private var dayNumber: String { "\(Calendar.current.component(.day, from: date))" }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 4) {

            Text(dayNumber)
                .font(.system(size: 16, weight: isToday || isWorkout ? .bold : .medium, design: .rounded))
                .foregroundColor(textColor)
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        if isToday {
                            Circle()
                                .fill(themeManager.current.primaryAccent)
                                .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 5, y: 2)
                        }
                    }
                )

            Circle()
                .fill(isWorkout ? (isToday ? .white : themeManager.current.primaryAccent) : Color.clear)
                .frame(width: 6, height: 6)
                .shadow(color: isWorkout ? themeManager.current.primaryAccent.opacity(0.5) : .clear, radius: 3)
        }
        .frame(height: 50) 
        .contentShape(Rectangle()) 
    }

    private var textColor: Color {
        if isToday {

            return .white
        }
        if isWorkout {

            return colorScheme == .dark ? .white : .black
        }

        return colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)
    }
}

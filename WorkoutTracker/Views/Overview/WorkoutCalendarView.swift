//
//  WorkoutCalendarView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 25.12.25.
//
//  Экран календаря.
//  Отображает:
//  1. Статистику количества тренировок за выбранный период.
//  2. Вертикальный скролл месяцев.
//  3. Визуальную индикацию дней с тренировками (зеленые ячейки).
//

internal import SwiftUI
import SwiftData

// MARK: - Main View

struct WorkoutCalendarView: View {
    
    // MARK: - Nested Types
    
    enum TimeRange: String, CaseIterable {
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
        case all = "All Time" // ДОБАВЛЕНО: Опция за все время
        
        var days: Int {
            switch self {
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            case .all: return Int.max
            }
        }
    }
    
    // MARK: - Environment & State
    @Environment(\.modelContext) private var context
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // ОПТИМИЗАЦИЯ: Мы больше не грузим всю базу. Только 2 крайние тренировки,
    // чтобы знать, есть ли что-то в базе и с какого месяца начинать.
    @Query private var recentWorkoutsTrigger: [Workout]
    @Query private var oldestWorkoutQuery: [Workout]
    
    @State private var selectedTimeRange: TimeRange = .month
    @State private var totalWorkoutCount: Int = 0
    
    init() {
        var descTrigger = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descTrigger.fetchLimit = 1
        _recentWorkoutsTrigger = Query(descTrigger)
        
        var descOldest = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .forward)])
        descOldest.fetchLimit = 1
        _oldestWorkoutQuery = Query(descOldest)
    }
    
    // MARK: - Computed Properties
    
    /// Список дат (первые числа месяцев) для отображения в календаре
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
            if let oldestWorkout = oldestWorkoutQuery.first {
                let components = calendar.dateComponents([.month], from: oldestWorkout.date, to: today)
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

    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            statsHeader
            Divider()
            calendarList
        }
        .navigationTitle(LocalizedStringKey("Calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateWorkoutCount()
        }
    }
    
    // MARK: - View Components
    
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
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
            }
            .animation(.default, value: totalWorkoutCount)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var calendarList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if recentWorkoutsTrigger.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: LocalizedStringKey("No workouts yet"),
                        message: LocalizedStringKey("Start tracking your workouts to see them appear on the calendar. Each completed workout will be highlighted!")
                    )
                    .padding(.top, 50)
                } else {
                    VStack(spacing: 25) {
                        ForEach(monthsToDisplay.indices, id: \.self) { index in
                            // Передаем дату начала месяца. Запрос в базу делает сам MonthView!
                            MonthView(monthDate: monthsToDisplay[index])
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
    
    private func updateWorkoutCount() {
        let calendar = Calendar.current
        let cutoff: Date
        if selectedTimeRange == .all {
            cutoff = Date.distantPast
        } else {
            cutoff = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        }
        
        let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.date >= cutoff })
        // fetchCount работает за долю секунды, в отличие от fetch
        totalWorkoutCount = (try? context.fetchCount(desc)) ?? 0
    }
}

// MARK: - Month Component

struct MonthView: View {
    
    let monthDate: Date
    
    // ОПТИМИЗАЦИЯ: Каждый месяц запрашивает ТОЛЬКО свои собственные тренировки (максимум ~30 штук).
    @Query private var monthWorkouts: [Workout]
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    init(monthDate: Date) {
        self.monthDate = monthDate
        
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: monthDate))!
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        
        var desc = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.date >= start && $0.date < end }
        )
        // Нам нужны только даты, поэтому исключаем тяжелые вложенные объекты для календаря
        _monthWorkouts = Query(desc)
    }
    
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
        VStack(alignment: .leading, spacing: 10) {
            Text(monthTitle)
                .font(.title3)
                .bold()
                .foregroundColor(.blue)
            
            weekDaysHeader
            daysGrid
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var weekDaysHeader: some View {
        HStack {
            ForEach(0..<7, id: \.self) { index in
                let daySymbolIndex = (calendar.firstWeekday - 1 + index) % 7
                Text(calendar.shortWeekdaySymbols[daySymbolIndex].prefix(1))
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var daysGrid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<firstDayOffset, id: \.self) { _ in
                Color.clear.frame(height: 30)
            }
            
            ForEach(daysInMonth, id: \.self) { date in
                dayView(for: date)
            }
        }
    }
    
    @ViewBuilder
    private func dayView(for date: Date) -> some View {
        if let workoutIndex = monthWorkouts.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            NavigationLink(destination: WorkoutDetailView(workout: monthWorkouts[workoutIndex])) {
                DayCell(date: date, isWorkout: true)
            }
            .buttonStyle(PlainButtonStyle())
            
        } else {
            DayCell(date: date, isWorkout: false)
        }
    }
}

// MARK: - Day Cell Component

struct DayCell: View {
    let date: Date
    let isWorkout: Bool
    
    private var dayNumber: String { "\(Calendar.current.component(.day, from: date))" }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if isToday {
                        RoundedRectangle(cornerRadius: 6).stroke(Color.blue, lineWidth: 2)
                    }
                }
            
            Text(dayNumber)
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(textColor)
        }
    }
    
    private var backgroundColor: Color { isWorkout ? Color.green : Color.gray.opacity(0.1) }
    private var textColor: Color { isWorkout ? .white : (isToday ? .blue : .primary) }
}


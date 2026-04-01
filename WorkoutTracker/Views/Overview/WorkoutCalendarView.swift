
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

// 🎼 ОПТИМИЗАЦИЯ: Легкая структура для передачи между потоками (Background -> Main)
struct MiniWorkout: Sendable {
    let date: Date
    let id: PersistentIdentifier
}

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
    
    @State private var selectedTimeRange: TimeRange = .month
    @State private var totalWorkoutCount: Int = 0
    
    // 🎼 ОПТИМИЗАЦИЯ: Храним сгруппированные данные в оперативной памяти
    @State private var workoutsByMonth: [Int: [MiniWorkout]] = [:] // Ключ: (Год * 100) + Месяц
    @State private var allMiniWorkouts: [MiniWorkout] = []
    @State private var oldestWorkoutDate: Date? = nil
    @State private var isLoaded: Bool = false
    
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

    // MARK: - Body
    
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
        .navigationTitle(LocalizedStringKey("Calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCalendarData()
        }
    }
    
    // MARK: - Data Loading (Background Task)
    
    private func loadCalendarData() {
        let container = context.container
        
        Task.detached(priority: .userInitiated) {
            let bgContext = ModelContext(container)
            
            // 🎼 ОПТИМИЗАЦИЯ: Извлекаем все тренировки ОДНИМ легким запросом в фоновом потоке
            let desc = FetchDescriptor<Workout>()
            let allWorkouts = (try? bgContext.fetch(desc)) ?? []
            
            // Маппим в безопасные для потоков (Sendable) легковесные структуры
            let miniWorkouts = allWorkouts.map { MiniWorkout(date: $0.date, id: $0.persistentModelID) }
            let oldest = miniWorkouts.min(by: { $0.date < $1.date })?.date
            
            var dict: [Int: [MiniWorkout]] = [:]
            let calendar = Calendar.current
            
            // Группируем по месяцам: Ключ = Год*100 + Месяц (например, 202512)
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
        
        // Быстрая фильтрация в оперативной памяти (без обращения к базе)
        totalWorkoutCount = allMiniWorkouts.filter { $0.date >= cutoff }.count
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
                            
                            // Передаем только тренировки для этого конкретного месяца
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

// MARK: - Month Component

struct MonthView: View {
    let monthDate: Date
    let monthWorkouts: [MiniWorkout]
    
    @Environment(\.modelContext) private var context
    
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
        // Поиск в массиве локальных данных происходит мгновенно
        if let mw = monthWorkouts.first(where: { calendar.isDate($0.date, inSameDayAs: date) }),
           let workout = context.model(for: mw.id) as? Workout {
            
            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
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

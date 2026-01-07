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

// MARK: - Main View

struct WorkoutCalendarView: View {
    
    // MARK: - Nested Types
    
    enum TimeRange: String, CaseIterable {
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
        
        var days: Int {
            switch self {
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            }
        }
    }
    
    // MARK: - Environment & State
    
    @EnvironmentObject var viewModel: WorkoutViewModel
    @State private var selectedTimeRange: TimeRange = .month
    
    // MARK: - Computed Properties
    
    /// Количество тренировок за выбранный период (фильтрация по дате)
    private var workoutCount: Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return viewModel.workouts.filter { $0.date >= cutoffDate }.count
    }
    
    /// Список дат (первые числа месяцев) для отображения в календаре
    /// Генерирует месяцы назад от текущего месяца в зависимости от выбранного диапазона
    private var monthsToDisplay: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        // Нормализуем текущую дату к первому дню текущего месяца
        guard let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return []
        }
        
        let monthsToShow: Int
        switch selectedTimeRange {
        case .month:
            // Только текущий месяц (1 месяц)
            monthsToShow = 1
        case .threeMonths:
            // Текущий месяц и 2 предыдущих (3 месяца)
            monthsToShow = 3
        case .year:
            // Текущий месяц и 11 предыдущих (12 месяцев)
            monthsToShow = 12
        }
        
        // Генерируем месяцы назад: от текущего месяца к самому старому
        // Порядок: сначала текущий месяц (i=0), затем месяц назад (i=1), и так далее
        // Текущий месяц будет сверху в списке
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
            // 1. Блок статистики сверху
            statsHeader
            
            Divider()
            
            // 2. Скролл календаря
            calendarList
        }
        .navigationTitle(LocalizedStringKey("Calendar"))
        .navigationBarTitleDisplayMode(.inline)
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
            
            HStack(alignment: .lastTextBaseline) {
                Text("\(workoutCount)")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                
                Text(LocalizedStringKey("workouts done"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
            }
            .animation(.default, value: workoutCount)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var calendarList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.workouts.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: LocalizedStringKey("No workouts yet"),
                        message: LocalizedStringKey("Start tracking your workouts to see them appear on the calendar. Each completed workout will be highlighted!")
                    )
                    .padding(.top, 50)
                } else {
                    VStack(spacing: 25) {
                        ForEach(monthsToDisplay.indices, id: \.self) { index in
                            // ViewModel передается через Environment, поэтому MonthView найдет его сам
                            MonthView(monthDate: monthsToDisplay[index])
                                .id(index)
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: selectedTimeRange) { _ in
                // При изменении диапазона прокручиваем к началу (к текущему месяцу)
                if !monthsToDisplay.isEmpty {
                    proxy.scrollTo(0, anchor: .top)
                }
            }
        }
    }
}

// MARK: - Month Component

struct MonthView: View {
    
    // MARK: - Properties
    
    let monthDate: Date
    
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    // MARK: - Computed Properties (Date Logic)
    
    var monthTitle: String {
        monthDate.formatted(.dateTime.month(.wide).year())
    }
    
    /// Массив всех дней в месяце
    var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))
        else { return [] }
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    /// Смещение первого дня месяца относительно начала недели (пустые ячейки)
    var firstDayOffset: Int {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let firstWeekdaySystem = calendar.firstWeekday
        // Математика для корректного смещения с учетом настроек календаря (Пн/Вс)
        return (weekday - firstWeekdaySystem + 7) % 7
    }

    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Название месяца
            Text(monthTitle)
                .font(.title3)
                .bold()
                .foregroundColor(.blue)
            
            // Дни недели (Пн, Вт...)
            weekDaysHeader
            
            // Сетка дней
            daysGrid
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Subviews
    
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
            // Пустые ячейки (смещение начала месяца)
            ForEach(0..<firstDayOffset, id: \.self) { _ in
                Color.clear.frame(height: 30)
            }
            
            // Дни месяца
            ForEach(daysInMonth, id: \.self) { date in
                dayView(for: date)
            }
        }
    }
    
    @ViewBuilder
    private func dayView(for date: Date) -> some View {
        // Ищем, есть ли тренировка в этот день
        if let workoutIndex = viewModel.workouts.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            
            // Если ЕСТЬ -> Ссылка на детали
            NavigationLink(destination: WorkoutDetailView(workout: $viewModel.workouts[workoutIndex])) {
                DayCell(date: date, isWorkout: true)
            }
            .buttonStyle(PlainButtonStyle())
            
        } else {
            // Если НЕТ -> Просто ячейка
            DayCell(date: date, isWorkout: false)
        }
    }
}

// MARK: - Day Cell Component

struct DayCell: View {
    let date: Date
    let isWorkout: Bool
    
    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        ZStack {
            // Фон
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if isToday {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                }
            
            // Число
            Text(dayNumber)
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(textColor)
        }
    }
    
    // MARK: - Style Helpers
    
    private var backgroundColor: Color {
        if isWorkout { return Color.green }
        return Color.gray.opacity(0.1)
    }
    
    private var textColor: Color {
        if isWorkout { return .white }
        if isToday { return .blue }
        return .primary
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkoutCalendarView()
            .environmentObject(WorkoutViewModel())
    }
}

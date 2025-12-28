//
//  WorkoutCalendarView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 25.12.25.
//

internal import SwiftUI

struct WorkoutCalendarView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    
    // Статистика сверху
    @State private var selectedTimeRange: TimeRange = .month
    
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
    
    var workoutCount: Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return viewModel.workouts.filter { $0.date >= cutoffDate }.count
    }
    
    // Генерируем месяцы ОТ СЕГОДНЯ и В БУДУЩЕЕ
    var monthsToDisplay: [Date] {
        let calendar = Calendar.current
        let today = Date()
        var months: [Date] = []
        
        for i in 0...12 {
            if let date = calendar.date(byAdding: .month, value: i, to: today) {
                months.append(date)
            }
        }
        return months
    }

    var body: some View {
        VStack(spacing: 0) {
            
            // 1. Блок статистики
            VStack(spacing: 10) {
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        // Было: Text(range.rawValue)
                        Text(LocalizedStringKey(range.rawValue)).tag(range) // <--- СТАЛО
                    }
                }
                .pickerStyle(.segmented)
                
                HStack(alignment: .lastTextBaseline) {
                    Text("\(workoutCount)")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    
                    Text("workouts done")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 6)
                }
                .animation(.default, value: workoutCount)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // 2. Вертикальный календарь
            ScrollView {
                VStack(spacing: 25) {
                    ForEach(monthsToDisplay, id: \.self) { date in
                        // Передаем viewModel, чтобы внутри можно было создавать Binding к тренировкам
                        MonthView(monthDate: date)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// --- КОМПОНЕНТ ОДНОГО МЕСЯЦА ---

struct MonthView: View {
    let monthDate: Date
    // Нам нужен доступ к ViewModel, чтобы найти Binding ($workout)
    @EnvironmentObject var viewModel: WorkoutViewModel
    
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
            
            // Дни недели
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
            
            // Сетка дней
            LazyVGrid(columns: columns, spacing: 6) {
                // Пустые ячейки
                ForEach(0..<firstDayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 30)
                }
                
                // Дни месяца
                ForEach(daysInMonth, id: \.self) { date in
                    
                    // 1. Ищем, есть ли тренировка в этот день
                    // Мы ищем ПЕРВУЮ тренировку в этот день (обычно она одна)
                    if let workoutIndex = viewModel.workouts.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                        
                        // 2. Если ЕСТЬ -> Создаем NavigationLink
                        NavigationLink(destination: WorkoutDetailView(workout: $viewModel.workouts[workoutIndex])) {
                            DayCell(date: date, isWorkout: true)
                        }
                        .buttonStyle(PlainButtonStyle()) // Чтобы не красилось в стандартный синий цвет ссылки
                        
                    } else {
                        // 3. Если НЕТ -> Просто отображаем ячейку (некликабельную)
                        DayCell(date: date, isWorkout: false)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// --- ЯЧЕЙКА ДНЯ ---
struct DayCell: View {
    let date: Date
    let isWorkout: Bool
    
    var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }
    
    var isToday: Bool {
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
    
    var backgroundColor: Color {
        if isWorkout { return Color.green }
        return Color.gray.opacity(0.1)
    }
    
    var textColor: Color {
        if isWorkout { return .white }
        if isToday { return .blue }
        return .primary
    }
}

#Preview {
    NavigationStack {
        WorkoutCalendarView()
            .environmentObject(WorkoutViewModel())
    }
}

import WidgetKit
import SwiftUI

// 1. Провайдер данных (Таймлайн)
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        // Заглушка для превью
        SimpleEntry(date: Date(), data: WidgetData(streak: 5, weeklyTarget: 3, weeklyStats: [
            .init(label: "7/13", count: 3),
            .init(label: "7/20", count: 2),
            .init(label: "7/27", count: 4),
            .init(label: "8/3", count: 3),
            .init(label: "8/10", count: 1),
            .init(label: "8/17", count: 3)
        ]))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let data = WidgetDataManager.load()
        let entry = SimpleEntry(date: Date(), data: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Загружаем реальные данные из общей памяти
        let data = WidgetDataManager.load()
        let entry = SimpleEntry(date: Date(), data: data)
        
        // Обновляем виджет каждые 30 минут или при заходе в приложение
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// --------------------------------------------------------
// ВИДЖЕТ 1: ГРАФИК (КАК НА КАРТИНКЕ)
// --------------------------------------------------------

struct ChartWidgetView : View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading) {
            // Заголовок
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(.blue)
                    .padding(6)
                    .background(Circle().fill(Color.blue.opacity(0.2)))
                
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("Workouts"))
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text(LocalizedStringKey("Per Week"))
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                Spacer()
            }
            .padding(.bottom, 5)
            
            // График
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(entry.data.weeklyStats) { stat in
                    VStack {
                        // Столбик
                        ZStack(alignment: .bottom) {
                            // Фон столбика (пустой)
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 12, height: 60)
                            
                            // Заполненная часть (Сегменты)
                            VStack(spacing: 2) {
                                // Рисуем кубики снизу вверх
                                ForEach(0..<min(stat.count, 6), id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.purple)
                                        .frame(width: 12, height: 12) // Высота сегмента
                                        .cornerRadius(2)
                                }
                            }
                            .padding(.bottom, 0)
                            
                            // Линия цели (Target Line)
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color.purple.opacity(0.5))
                                    .frame(height: 1)
                                    .offset(y: -38) // Подбираем высоту под цель (3 тренировки * (12+2) ~= 42)
                            }
                        }
                        
                        // Дата
                        Text(stat.label)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.white
        }
    }
}

struct WeeklyChartWidget: Widget {
    let kind: String = "WeeklyChartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ChartWidgetView(entry: entry)
        }
        .configurationDisplayName("Workouts Per Week")
        .description("Track your weekly consistency.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// --------------------------------------------------------
// ВИДЖЕТ 2: ОГОНЕК (STREAK)
// --------------------------------------------------------

struct StreakWidgetView : View {
    var entry: Provider.Entry
    
    var body: some View {
        ZStack {
            // Градиентный фон
            LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
            
            VStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                
                Text("\(entry.data.streak)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(value: Double(entry.data.streak)))
                
                Text(LocalizedStringKey("Day Streak"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))
                    .textCase(.uppercase)
            }
        }
        .containerBackground(for: .widget) {
             LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak Flame")
        .description("Keep the fire burning!")
        .supportedFamilies([.systemSmall])
    }
}

// --------------------------------------------------------
// БАНДЛ (ЧТОБЫ БЫЛО 2 ВИДЖЕТА)
// --------------------------------------------------------

@main
struct WorkoutTrackerWidgets: WidgetBundle {
    var body: some Widget {
        WeeklyChartWidget()
        StreakWidget()
    }
}

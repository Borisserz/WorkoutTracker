

import WidgetKit
internal import SwiftUI
import AppIntents 

struct WidgetTheme {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let surface = Color(red: 0.1, green: 0.1, blue: 0.12)

    static let primaryCyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    static let primaryPurple = Color(red: 0.6, green: 0.2, blue: 1.0)

    static let neonGradient = LinearGradient(colors: [primaryPurple, primaryCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let fireGradient = LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct StatsEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct StatsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), data: WidgetData(
            streak: 12,
            weeklyTarget: 4,
            weeklyStats: [
                .init(label: "Mon", count: 1), .init(label: "Wed", count: 2), .init(label: "Fri", count: 1)
            ],
            recoveredMuscles: ["Legs", "Core"],
            aiTip: "Legs are fully charged. Don't skip leg day!",
            totalVolumeTons: 14.5
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> ()) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> ()) {
        let data = WidgetDataManager.load()
        let entry = StatsEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct ProStreakWidgetView: View {
    var entry: StatsEntry
    @Environment(\.widgetFamily) var family

    var currentWeeklyCount: Int {
        entry.data.weeklyStats.reduce(0) { $0 + $1.count }
    }

    var progress: Double {
        min(1.0, Double(currentWeeklyCount) / Double(max(entry.data.weeklyTarget, 1)))
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .accessoryCircular:
                lockScreenCircularView
            default:
                smallView
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryCircular { Color.clear } else { WidgetTheme.background }
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(WidgetTheme.fireGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundStyle(WidgetTheme.fireGradient)
                        .shadow(color: .orange.opacity(0.5), radius: 5)
                    Text("\(entry.data.streak)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 80, height: 80)

            Text("\(currentWeeklyCount)/\(entry.data.weeklyTarget) This Week")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private var mediumView: some View {
        HStack(spacing: 20) {
            smallView
            Divider().background(Color.white.opacity(0.1)).padding(.vertical, 10)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Activity").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Spacer()
                    Text("\(String(format: "%.1f", entry.data.totalVolumeTons))T").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(WidgetTheme.primaryCyan)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    let maxCount = max(entry.data.weeklyStats.map { $0.count }.max() ?? 1, 1)
                    ForEach(entry.data.weeklyStats) { stat in
                        VStack(spacing: 4) {
                            GeometryReader { geo in
                                VStack {
                                    Spacer()
                                    Capsule()
                                        .fill(WidgetTheme.neonGradient)
                                        .frame(height: max(10, geo.size.height * CGFloat(stat.count) / CGFloat(maxCount)))
                                        .shadow(color: WidgetTheme.primaryPurple.opacity(0.4), radius: 4, y: 2)
                                }
                            }
                            Text(String(stat.label.prefix(3)))
                                .font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var lockScreenCircularView: some View {
        Gauge(value: progress) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(entry.data.streak)").font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(WidgetTheme.fireGradient)
    }
}

struct ProStreakWidget: Widget {
    let kind: String = "ProStreakWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsWidgetProvider()) { entry in
            ProStreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Activity & Streak")
        .description("Track your weekly consistency and daily streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

struct AICoachWidgetView: View {
    var entry: StatsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemMedium: mediumView
            case .accessoryRectangular: lockScreenRectangularView
            default: EmptyView()
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryRectangular { Color.clear } else { WidgetTheme.background }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle().fill(WidgetTheme.neonGradient).frame(width: 28, height: 28).shadow(color: WidgetTheme.primaryCyan.opacity(0.6), radius: 6)
                        Image(systemName: "brain.head.profile").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    }
                    Text("AI Coach").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(WidgetTheme.neonGradient)
                }
                Text(entry.data.aiTip).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.9)).lineLimit(3).minimumScaleFactor(0.8)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Ready to Train:").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.5)).textCase(.uppercase)
                VStack(alignment: .leading, spacing: 6) {
                    if entry.data.recoveredMuscles.isEmpty {
                        Text("Need rest 🛏️").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(WidgetTheme.primaryCyan)
                    } else {
                        ForEach(entry.data.recoveredMuscles.prefix(3), id: \.self) { muscle in
                            HStack {
                                Image(systemName: "bolt.fill").foregroundColor(.yellow).font(.system(size: 10))
                                Text(muscle).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6).background(Color.white.opacity(0.1)).clipShape(Capsule())
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }

    private var lockScreenRectangularView: some View {
        HStack(alignment: .center) {
            Image(systemName: "brain.head.profile").font(.title3)
            VStack(alignment: .leading) {
                Text("AI Coach").font(.headline)
                Text(entry.data.recoveredMuscles.isEmpty ? "Take a rest day" : "Train: \(entry.data.recoveredMuscles.joined(separator: ", "))").font(.caption).lineLimit(1)
            }
        }
    }
}

struct AICoachWidget: Widget {
    let kind: String = "AICoachWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsWidgetProvider()) { entry in
            AICoachWidgetView(entry: entry)
        }
        .configurationDisplayName("AI Coach Status")
        .description("Get AI recommendations and muscle recovery status.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}

struct QuickActionsWidgetView: View {
    var entry: StatsEntry

    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Actions").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                actionButton(title: "Empty", icon: "plus", color: WidgetTheme.primaryCyan, action: "empty_workout")
                actionButton(title: "Smart", icon: "wand.and.stars", color: WidgetTheme.primaryPurple, action: "smart_builder")
                actionButton(title: "Weight", icon: "scalemass.fill", color: .orange, action: "log_weight")
            }
        }
        .containerBackground(for: .widget) { WidgetTheme.background }
    }

    private func actionButton(title: String, icon: String, color: Color, action: String) -> some View {
        Button(intent: OpenWorkoutAppIntent(actionType: action)) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundColor(color).shadow(color: color.opacity(0.5), radius: 4)
                }
                Text(title).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(WidgetTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionsWidget: Widget {
    let kind: String = "QuickActionsWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsWidgetProvider()) { entry in
            QuickActionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Actions")
        .description("Jump straight into your workout or AI Builder.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct WorkoutTrackerWidgets: WidgetBundle {
    var body: some Widget {
        ProStreakWidget()
        AICoachWidget()
        QuickActionsWidget()
    }
}

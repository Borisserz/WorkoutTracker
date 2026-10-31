import WidgetKit
import SwiftUI
import ActivityKit

private enum WidgetPastel {
    static let amber = Color(red: 0.984, green: 0.749, blue: 0.141) // #FBBF24
    static let sage = Color(red: 0.204, green: 0.780, blue: 0.349)  // #34C759
    static let oat = Color(red: 0.937, green: 0.890, blue: 0.827)   // #EFE3D3
}

@main
struct WorkoutTimerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let ex = context.state.currentExerciseName {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Далее").font(.caption2).foregroundColor(WidgetPastel.oat.opacity(0.7))
                            Text(ex).font(.caption).bold().foregroundColor(.white)
                        }
                    } else {
                        Label("Тренировка", systemImage: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundColor(WidgetPastel.sage)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let restEnd = context.state.restTimerEndTime {
                        Text(timerInterval: Date()...restEnd, countsDown: true)
                            .monospacedDigit().font(.title2).bold().foregroundColor(WidgetPastel.amber)
                            .frame(width: 90)
                    } else {
                        Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                            .monospacedDigit().font(.title2).bold().foregroundColor(WidgetPastel.sage)
                            .frame(width: 90)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let weight = context.state.upcomingWeight {
                        Text("Вес: \(weight)").font(.headline).foregroundColor(WidgetPastel.oat)
                    } else {
                        Text(context.attributes.workoutTitle).font(.headline).lineLimit(1)
                    }
                }
            } compactLeading: {
                if context.state.restTimerEndTime != nil {
                    Image(systemName: "timer").foregroundColor(WidgetPastel.amber).font(.title3)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional").foregroundColor(WidgetPastel.sage).font(.title3)
                }
            } compactTrailing: {
                if let restEnd = context.state.restTimerEndTime {
                    Text(timerInterval: Date()...restEnd, countsDown: true)
                        .monospacedDigit().frame(width: 50).font(.caption).foregroundColor(WidgetPastel.amber)
                } else {
                    Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                        .monospacedDigit().frame(width: 50).font(.caption).foregroundColor(WidgetPastel.sage)
                }
            } minimal: {
                if context.state.restTimerEndTime != nil {
                    Image(systemName: "timer").foregroundColor(WidgetPastel.amber)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional").foregroundColor(WidgetPastel.sage)
                }
            }
            .widgetURL(nil)
        }
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let ex = context.state.currentExerciseName {
                    Label("Отдых", systemImage: "timer")
                        .font(.caption2).foregroundStyle(WidgetPastel.amber)
                    Text("Далее: \(ex)")
                        .font(.headline).foregroundStyle(.white)
                    if let weight = context.state.upcomingWeight {
                        Text("Вес: \(weight)")
                            .font(.caption).foregroundStyle(WidgetPastel.oat.opacity(0.85))
                    }
                } else {
                    Label("Идет тренировка", systemImage: "record.circle")
                        .font(.caption2).foregroundStyle(WidgetPastel.sage)

                    Text(context.attributes.workoutTitle)
                        .font(.headline).foregroundStyle(.white)
                }
            }

            Spacer()

            if let restEnd = context.state.restTimerEndTime {
                Text(timerInterval: Date()...restEnd, countsDown: true)
                    .font(.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(WidgetPastel.amber)
            } else {
                Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                    .font(.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(WidgetPastel.sage)
            }
        }
        .padding()
    }
}

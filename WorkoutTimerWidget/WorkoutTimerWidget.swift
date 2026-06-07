import WidgetKit
import SwiftUI
import ActivityKit

@main
struct WorkoutTimerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in

            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let ex = context.state.currentExerciseName {
                        VStack(alignment: .leading) {
                            Text("Next").font(.caption2).foregroundColor(.gray)
                            Text(ex).font(.caption).bold()
                        }
                    } else {
                        Label("Workout", systemImage: "figure.strengthtraining.traditional")
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let restEnd = context.state.restTimerEndTime {
                        Text(timerInterval: Date()...restEnd, countsDown: true)
                            .monospacedDigit().font(.title2).foregroundColor(.orange)
                            .frame(width: 90)
                    } else {
                        Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                            .monospacedDigit().font(.title2).foregroundColor(.red)
                            .frame(width: 90)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let weight = context.state.upcomingWeight {
                        Text("Weight: \(weight)").font(.headline).foregroundColor(.orange)
                    } else {
                        Text(context.attributes.workoutTitle).font(.headline).lineLimit(1)
                    }
                }
            } compactLeading: {
                if context.state.restTimerEndTime != nil {
                    Image(systemName: "timer").foregroundColor(.orange).font(.title3)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional").foregroundColor(.red).font(.title3)
                }
            } compactTrailing: {
                if let restEnd = context.state.restTimerEndTime {
                    Text(timerInterval: Date()...restEnd, countsDown: true)
                        .monospacedDigit().frame(width: 50).font(.caption).foregroundColor(.orange)
                } else {
                    Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                        .monospacedDigit().frame(width: 50).font(.caption).foregroundColor(.red)
                }
            } minimal: {
                if context.state.restTimerEndTime != nil {
                    Image(systemName: "timer").foregroundColor(.orange)
                } else {
                    Image(systemName: "timer").foregroundColor(.red)
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
                    Label("Resting", systemImage: "timer")
                        .font(.caption2).foregroundStyle(.orange)
                    Text("Next: \(ex)")
                        .font(.headline).foregroundStyle(.white)
                    if let weight = context.state.upcomingWeight {
                        Text("Target: \(weight)")
                            .font(.caption).foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    Label("Live Workout", systemImage: "record.circle")
                        .font(.caption2).foregroundStyle(.red)

                    Text(context.attributes.workoutTitle)
                        .font(.headline).foregroundStyle(.white)
                }
            }

            Spacer()

            if let restEnd = context.state.restTimerEndTime {
                Text(timerInterval: Date()...restEnd, countsDown: true)
                    .font(.system(size: 32, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.orange)
            } else {
                Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                    .font(.system(size: 32, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }
}

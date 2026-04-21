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
                    Label("Workout", systemImage: "figure.strengthtraining.traditional")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                        .monospacedDigit().font(.title2).foregroundColor(.red)
                        .frame(width: 90) 
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.workoutTitle).font(.headline).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional").foregroundColor(.red).font(.title3)

            } compactTrailing: {
                Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                    .monospacedDigit().frame(width: 50).font(.caption).foregroundColor(.red)
            } minimal: {
                Image(systemName: "timer").foregroundColor(.red)
            }
            .widgetURL(nil)
        }
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Label("Live Workout", systemImage: "record.circle")
                    .font(.caption2).foregroundStyle(.red)

                Text(context.attributes.workoutTitle)
                    .font(.headline).foregroundStyle(.white)
            }

            Spacer()

            Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                .font(.system(size: 32, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding()
    }
}

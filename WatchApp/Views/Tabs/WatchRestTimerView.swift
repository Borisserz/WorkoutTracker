

internal import SwiftUI

struct WatchRestTimerView: View {
    @Bindable var viewModel: WatchActiveWorkoutViewModel
    @Environment(WatchWorkoutManager.self) private var workoutManager 

    var progress: Double {
        guard viewModel.initialRestTime > 0 else { return 0 }
        return Double(viewModel.restTimeRemaining) / Double(viewModel.initialRestTime)
    }

    var body: some View {
        ZStack {
            WatchTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                HStack(alignment: .top) {
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        viewModel.skipTimer()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(WatchTheme.buttonGray)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {

                        Text(Date(), format: .dateTime.hour().minute())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(WatchTheme.red)
                                .font(.system(size: 10))
                                .symbolEffect(.pulse, options: .repeating, isActive: workoutManager.isRunning)

                            Text("\(Int(workoutManager.heartRate))")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()

                Text(timeString(viewModel.restTimeRemaining))
                    .font(.system(size: 48, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WatchTheme.blue.opacity(0.3)) 
                        Capsule()
                            .fill(WatchTheme.blue)
                            .frame(width: max(0, geo.size.width * CGFloat(progress)))
                            .animation(.linear(duration: 1.0), value: progress)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                HStack {
                    Text(viewModel.nextSetInfo)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .lineSpacing(2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Spacer()

                HStack(spacing: 12) {
                    timerButton(title: "-15s", action: { viewModel.adjustTimer(by: -15) })
                    timerButton(title: "+15s", action: { viewModel.adjustTimer(by: 15) })
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
    }

    private func timerButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
            action()
        }) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(WatchTheme.buttonGray)
                .foregroundColor(.white)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ time: Int) -> String {
        let m = time / 60
        let s = time % 60
        return String(format: "%d:%02d", m, s)
    }
}

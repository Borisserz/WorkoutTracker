
//
//  WatchRestTimerView.swift.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 11.04.26.
//

// ============================================================
// FILE: WatchApp/Views/WatchRestTimerView.swift
// ============================================================
internal import SwiftUI

struct WatchRestTimerView: View {
    @Bindable var viewModel: WatchActiveWorkoutViewModel
    
    var progress: Double {
        guard viewModel.initialRestTime > 0 else { return 0 }
        return Double(viewModel.restTimeRemaining) / Double(viewModel.initialRestTime)
    }
    
    var body: some View {
        ZStack {
            WatchTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Skip
                HStack {
                    Spacer()
                    Button("Skip") {
                        WKInterfaceDevice.current().play(.click)
                        viewModel.skipTimer()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(WatchTheme.cyan)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer()
                
                // Huge Timer
                Text(timeString(viewModel.restTimeRemaining))
                    .font(.system(size: 70, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                // Thick Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(WatchTheme.primaryGradient)
                            .frame(width: max(0, geo.size.width * CGFloat(progress)))
                            .animation(.linear(duration: 1.0), value: progress)
                    }
                }
                .frame(height: 12)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                
                // Next Set Info
                Text(viewModel.nextSetInfo)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Spacer()
                
                // Adjust Controls
                HStack(spacing: 12) {
                    timerButton(title: "-15s", action: { viewModel.adjustTimer(by: -15) })
                    timerButton(title: "+15s", action: { viewModel.adjustTimer(by: 15) })
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
    }
    
    private func timerButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
            action()
        }) {
            Text(title)
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(WatchTheme.surfaceVariant)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func timeString(_ time: Int) -> String {
        let m = time / 60
        let s = time % 60
        return String(format: "%d:%02d", m, s)
    }
}

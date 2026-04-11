//
//  WatchRPEView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 11.04.26.
//

// ============================================================
// FILE: WatchApp/Views/WatchRPEView.swift
// ============================================================
internal import SwiftUI

struct WatchRPEView: View {
    @Bindable var viewModel: WatchActiveWorkoutViewModel
    @State private var rpe: Double = 7.0
    
    var body: some View {
        let intRPE = Int(rpe)
        let color = WatchRPEHelper.getColor(for: intRPE)
        let description = WatchRPEHelper.getDescription(for: intRPE)
        
        ZStack {
            WatchTheme.background.ignoresSafeArea()
            
            VStack(spacing: 4) {
                Text("Effort (RPE)")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .padding(.top, 10)
                
                Text("\(intRPE)")
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                
                Text(description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Skip") {
                        WKInterfaceDevice.current().play(.click)
                        viewModel.showRPE = false
                    }
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WatchTheme.surfaceVariant)
                    .cornerRadius(16)
                    
                    Button("Save") {
                        WKInterfaceDevice.current().play(.success)
                        // Note: To sync RPE to iOS, you'd extend your SyncPayload. For now, we dismiss.
                        viewModel.showRPE = false
                    }
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(color)
                    .foregroundColor(.black)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
        }
        .focusable()
        .digitalCrownRotation(
            $rpe,
            from: 1, through: 10, by: 1.0,
            sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true
        )
    }
}

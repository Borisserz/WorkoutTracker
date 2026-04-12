// ============================================================
// FILE: WatchApp/Views/Tabs/WatchRPEView.swift
// ============================================================
internal import SwiftUI

struct WatchRPEView: View {
    @Bindable var viewModel: WatchActiveWorkoutViewModel
    @State private var rpe: Double = 7.0
    
    var body: some View {
        let intRPE = Int(rpe)
        let description = WatchRPEHelper.getDescription(for: intRPE)
        
        ZStack {
            WatchTheme.background.ignoresSafeArea()
            
            VStack(spacing: 4) {
                // Info Header (From ViewModel)
                Text(viewModel.nextSetInfo.replacingOccurrences(of: "Next: ", with: ""))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 4)
                
                Spacer()
                
                // Big Number & RPE label
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(intRPE)")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    
                    Text("RPE")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Description Text
                Text(description)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    Button("Skip") {
                        WKInterfaceDevice.current().play(.click)
                        viewModel.showRPE = false
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WatchTheme.buttonGray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    
                    Button("Save") {
                        WKInterfaceDevice.current().play(.success)
                        Task { await viewModel.saveRPE(intRPE) }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WatchTheme.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 4)
        }
        .focusable()
        .digitalCrownRotation(
            $rpe,
            from: 1, through: 10, by: 1.0,
            sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true
        )
    }
}

//
//  WatchSummaryView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 11.04.26.
//

// ============================================================
// FILE: WatchApp/Views/WatchSummaryView.swift
// ============================================================
internal import SwiftUI

struct WatchSummaryView: View {
    @Bindable var viewModel: WatchActiveWorkoutViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            WatchTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .orange.opacity(0.5), radius: 10)
                        .padding(.top, 20)
                    
                    Text("Workout Complete")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 8) {
                        summaryRow(title: "Time", value: "45m", icon: "stopwatch.fill", color: WatchTheme.cyan) // Replace 45m with actual duration logic if needed
                        summaryRow(title: "Volume", value: "\(Int(viewModel.totalVolume)) kg", icon: "scalemass.fill", color: WatchTheme.purple)
                        summaryRow(title: "Sets", value: "\(viewModel.totalSets)", icon: "number.circle.fill", color: WatchTheme.green)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        WKInterfaceDevice.current().play(.success)
                        onDismiss()
                    }) {
                        Text("Done")
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(WatchTheme.primaryGradient)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func summaryRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 28, height: 28)
                Image(systemName: icon).font(.caption).foregroundColor(color)
            }
            Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
        }
        .padding()
        .background(WatchTheme.surface)
        .cornerRadius(16)
    }
}

// ============================================================
// FILE: WatchApp/Views/WatchSummaryView.swift
// ============================================================
internal import SwiftUI

struct WatchSummaryView: View {
    @Bindable var viewModel: WatchActiveWorkoutViewModel
    var onDismiss: () -> Void
    @Environment(WatchWorkoutManager.self) private var workoutManager
    var body: some View {
        ZStack {
            WatchTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Трофей и Заголовок
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
                    
                    // Блок статистики
                    VStack(spacing: 8) {
                        // 🛠️ FIX: Выводим время тренировки
                        summaryRow(title: "Time", value: formatTime(viewModel.totalDurationSeconds), icon: "stopwatch.fill", color: .orange)
                        
                        summaryRow(title: "Volume", value: "\(Int(viewModel.totalVolume)) kg", icon: "scalemass.fill", color: .purple)
                        
                        summaryRow(title: "Sets", value: "\(viewModel.totalSets)", icon: "number.circle.fill", color: WatchTheme.green)
                        
                        summaryRow(title: "Calories", value: "\(Int(workoutManager.activeEnergy)) kcal", icon: "flame.fill", color: .red)
                    }
                    .padding(.horizontal)
                    
                    // Кнопка Done
                    Button(action: {
                        WKInterfaceDevice.current().play(.success)
                        onDismiss()
                    }) {
                        Text("Done")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(WatchTheme.blue)
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
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding()
        .background(WatchTheme.cardBackground)
        .cornerRadius(16)
    }
    
    // 🛠️ FIX: Метод для красивого форматирования секунд
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 {
            return "\(m)m \(s)s"
        } else {
            return "\(s)s"
        }
    }
}

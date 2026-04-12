//
//  TimerSetupSheet.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 6.04.26.
//

internal import SwiftUI


struct TimerSetupSheet: View {
    @Environment(RestTimerManager.self) var timerManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var minutes: Int = 1
    @State private var seconds: Int = 30
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                ZStack {
                    Circle()
                        .fill(themeManager.current.primaryAccent.opacity(0.1))
                        .frame(width: 70, height: 70)
                    Image(systemName: "timer")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(themeManager.current.primaryAccent)
                }
                .padding(.top, 24)
                
                Text(LocalizedStringKey("Rest Timer Duration"))
                    .font(.title2)
                    .bold()
                
                // Native Wheel Pickers (Увеличенный размер)
                HStack(spacing: 0) {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { min in
                            Text("\(min) m").tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 180) // ✅ FIX: Показывает больше цифр
                    .clipped()
                    
                    Picker("Seconds", selection: $seconds) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { sec in
                            Text("\(sec) s").tag(sec)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 180) // ✅ FIX: Показывает больше цифр
                    .clipped()
                }
                .padding(.horizontal)
                .background(themeManager.current.surface.cornerRadius(20))
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("Cancel"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(themeManager.current.surface)
                            .foregroundColor(themeManager.current.primaryText)
                            .cornerRadius(16)
                    }
                    
                    Button {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        let totalSeconds = (minutes * 60) + seconds
                        timerManager.startRestTimer(duration: totalSeconds > 0 ? totalSeconds : 60)
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("Start"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(themeManager.current.primaryAccent)
                            .foregroundColor(themeManager.current.background)
                            .cornerRadius(16)
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
            .onAppear {
                let defaultSecs = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.defaultRestTime.rawValue)
                let initial = defaultSecs > 0 ? defaultSecs : 90
                minutes = initial / 60
                seconds = (initial % 60) / 5 * 5
            }
        }
        .presentationDetents([.height(460)]) // Чуть увеличили шторку для барабанов
        .presentationDragIndicator(.visible)
    }
}

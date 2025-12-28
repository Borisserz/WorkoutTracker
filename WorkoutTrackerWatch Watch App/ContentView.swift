//
//  ContentView.swift
//  WorkoutTrackerWatch Watch App
//
//  Created by Boris Serzhanovich on 28.12.25.
//

// WorkoutTrackerWatch/ContentView.swift

import SwiftUI

struct ContentView: View {
    @ObservedObject var connector = ConnectivityManager.shared
    
    var body: some View {
        if let state = connector.receivedState, state.workoutActive {
            ScrollView {
                VStack(spacing: 15) {
                    // Заголовок
                    Text(state.exerciseName)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                    
                    Divider()
                    
                    // Данные
                    HStack {
                        VStack {
                            Text("\(Int(state.weight))")
                                .font(.title2).bold()
                            Text("kg").font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        VStack {
                            Text("\(state.reps)")
                                .font(.title2).bold()
                            Text("reps").font(.caption).foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Таймер или Кнопка
                    if state.timerActive {
                        // ТАЙМЕР
                        VStack {
                            Text(timeString(time: state.timerTime))
                                .font(.system(size: 40, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                            Text("Resting...")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(12)
                    } else {
                        // КНОПКА "СДЕЛАНО"
                        Button(action: {
                            // Шлем команду на телефон
                            ConnectivityManager.shared.sendActionToPhone(action: "finishSet")
                        }) {
                            Text("Finish Set")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(25)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        } else {
            // Состояние покоя
            VStack {
                Image(systemName: "figure.run")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("Start workout on iPhone")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    func timeString(time: Int) -> String {
        let m = time / 60
        let s = time % 60
        return String(format: "%02d:%02d", m, s)
    }
}
#Preview {
    ContentView()
}

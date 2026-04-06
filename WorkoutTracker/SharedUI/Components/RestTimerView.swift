// ============================================================
// FILE: WorkoutTracker/SharedUI/Components/RestTimerView.swift
// ============================================================

internal import SwiftUI

struct RestTimerView: View {
    @Environment(RestTimerManager.self) var timerManager
    @State private var isPulsing = false
    
    var body: some View {
        if timerManager.isRestTimerActive {
            VStack(spacing: 0) {
                // ✅ FIX: Progress bar is now in its own container for visual separation
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.black.opacity(0.2))
                        
                        Rectangle()
                            .fill(timerManager.restTimerFinished ? Color.green : Color.blue)
                            .frame(width: geo.size.width * CGFloat(timerManager.progress))
                            .animation(.linear(duration: 1.0), value: timerManager.progress)
                    }
                }
                .frame(height: 4)
                
                // Main timer content
                VStack(spacing: 16) {
                    Group {
                        if timerManager.restTimerFinished {
                            // ✅ FIX: Replaced "DONE" text with a large, animated checkmark icon
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 52, weight: .bold))
                                .foregroundColor(.green)
                                .symbolEffect(.bounce, value: timerManager.restTimerFinished)
                        } else {
                            Text(timeString(time: timerManager.restTimeRemaining))
                                .font(.system(size: 56, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                                .animation(.default, value: timerManager.restTimeRemaining)
                        }
                    }
                    .frame(height: 60) // Fixed height to prevent layout shifts
                    
                    // Controls
                    HStack(spacing: 12) {
                        if !timerManager.restTimerFinished {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                timerManager.subtractRestTime(15)
                            } label: {
                                Text("-15s")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(UIColor.secondarySystemFill))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                            }
                            
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                timerManager.addRestTime(15)
                            } label: {
                                Text("+15s")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(UIColor.secondarySystemFill))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                            }
                        }
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                timerManager.stopRestTimer()
                            }
                        } label: {
                            Text(timerManager.restTimerFinished ? LocalizedStringKey("Dismiss") : LocalizedStringKey("Skip"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(timerManager.restTimerFinished ? Color.green : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: (timerManager.restTimerFinished ? Color.green : Color.blue).opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
            .scaleEffect(isPulsing ? 1.02 : 1.0)
            .onChange(of: timerManager.restTimerFinished) { _, finished in
                if finished {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
        }
    }
    
    private func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

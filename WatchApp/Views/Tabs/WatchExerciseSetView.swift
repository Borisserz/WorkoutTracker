// ============================================================
// FILE: WatchApp/Views/Tabs/WatchExerciseSetView.swift
// ============================================================
internal import SwiftUI

enum CrownFocus {
    case weightMode
    case repsMode
}

struct WatchExerciseSetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: WatchActiveWorkoutViewModel
    let exerciseIndex: Int
    
    @State private var weight: Double = 20.0
    @State private var reps: Double = 10.0
    @State private var focus: CrownFocus = .weightMode
    
    private var crownBinding: Binding<Double> {
        Binding(
            get: { focus == .weightMode ? weight : reps },
            set: { newValue in
                if focus == .weightMode { weight = max(0, newValue) } else { reps = max(1, newValue) }
            }
        )
    }
    
    var body: some View {
        let exerciseName = viewModel.exercises[exerciseIndex].name
        
        ZStack {
            WatchTheme.background.ignoresSafeArea()
            
            VStack(spacing: 8) {
                Text(exerciseName)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(WatchTheme.cyan)
                    .lineLimit(1)
                    .padding(.top, 4)
                
                HStack(spacing: 8) {
                    inputButton(title: "WEIGHT", value: String(format: "%.1f", weight), type: .weightMode, activeColor: WatchTheme.purple)
                    inputButton(title: "REPS", value: "\(Int(reps))", type: .repsMode, activeColor: WatchTheme.cyan)
                }
                .padding(.vertical, 4)
                
                Button {
                    WKInterfaceDevice.current().play(.click)
                    Task {
                        await viewModel.logSet(for: exerciseIndex, weight: weight, reps: Int(reps))
                        dismiss()
                    }
                } label: {
                    Text("Log Set")
                        .font(.headline.bold())
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(WatchTheme.green)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
        .navigationBarHidden(true)
        .focusable()
        .digitalCrownRotation(
            crownBinding,
            from: 0, through: 500, by: focus == .weightMode ? 2.5 : 1.0,
            sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true
        )
        .onAppear {
            // Auto-fill from last set if exists
            let sets = viewModel.exercises[exerciseIndex].setsList ?? []
            if let last = sets.last {
                weight = last.weight ?? 20.0
                reps = Double(last.reps ?? 10)
            }
        }
    }
    
    private func inputButton(title: String, value: String, type: CrownFocus, activeColor: Color) -> some View {
        let isFocused = focus == type
        return Button {
            withAnimation { focus = type }
            WKInterfaceDevice.current().play(.click)
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isFocused ? activeColor : .gray)
                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isFocused ? activeColor.opacity(0.15) : WatchTheme.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isFocused ? activeColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

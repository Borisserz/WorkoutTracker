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
    
    @State private var currentSetIndex: Int = 1
    @State private var weight: Double = 0.0
    @State private var reps: Double = 0.0
    @State private var focus: CrownFocus = .repsMode
    @State private var isCurrentSetCompleted = false
    
    private var crownBinding: Binding<Double> {
        Binding(
            get: { focus == .weightMode ? weight : reps },
            set: { newValue in
                if focus == .weightMode { weight = max(0, newValue) } else { reps = max(0, newValue) }
            }
        )
    }
    
    var body: some View {
           let exercise = viewModel.exercises[exerciseIndex]
           // ✅ ИСПРАВЛЕНИЕ: "Всего сетов" - это просто реальное количество сетов в массиве.
           // Это автоматически учтет добавленные и удаленные сеты.
           let displayTotalSets = (exercise.setsList ?? []).count
           
           ZStack {
            WatchTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 8) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(WatchTheme.cyan)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                    
                    VStack(spacing: 2) {
                        Text(exercise.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text("Set \(currentSetIndex) of \(displayTotalSets)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(WatchTheme.cyan)
                    }
                    
                    HStack(spacing: 8) {
                        inputButton(title: "KG", value: String(format: "%.1f", weight), type: .weightMode)
                        inputButton(title: "REPS", value: "\(Int(reps))", type: .repsMode)
                    }
                    .padding(.vertical, 4)
                    
                    HStack(spacing: 12) {
                        Button { changeSet(by: -1) } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 44, height: 44)
                                .background(WatchTheme.buttonGray)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(currentSetIndex <= 1)
                        .opacity(currentSetIndex <= 1 ? 0.3 : 1.0)
                        
                        Button {
                            Task {
                                await viewModel.logSpecificSet(exerciseIndex: exerciseIndex, setIndex: currentSetIndex, weight: weight, reps: Int(reps))
                                
                                if currentSetIndex < displayTotalSets {
                                    changeSet(by: 1)
                                } else {
                                    isCurrentSetCompleted = true
                                }
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .heavy))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(isCurrentSetCompleted ? WatchTheme.blue.opacity(0.5) : WatchTheme.blue)
                                .foregroundColor(.white)
                                .cornerRadius(22)
                        }
                        .buttonStyle(.plain)
                        
                        Button { changeSet(by: 1) } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 44, height: 44)
                                .background(WatchTheme.buttonGray)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(currentSetIndex >= displayTotalSets)
                        .opacity(currentSetIndex >= displayTotalSets ? 0.3 : 1.0)
                    }
                    
                    if currentSetIndex > 1 {
                        if let prevSet = exercise.setsList?.first(where: { $0.index == currentSetIndex - 1 }) {
                            Text("Previous: \(String(format: "%.1f", prevSet.weight ?? 0))kg x \(prevSet.reps ?? 0)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.top, 2)
                        }
                    }
                    
                    optionsMenu
                        .padding(.top, 16)
                }
                .padding(.horizontal, 4)
            }
        }
        .navigationBarHidden(true)
        .focusable()
        .digitalCrownRotation(crownBinding, from: 0, through: 500, by: focus == .weightMode ? 2.5 : 1.0, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear { setupInitialSet() }
        // 🛠️ FIX: Никаких вызовов модалок отсюда! Все перехвачено родителем.
        .onChange(of: viewModel.goBackToWorkoutView) { _, shouldGoBack in
            if shouldGoBack {
                dismiss()
            }
        }
    }
    
    private func inputButton(title: String, value: String, type: CrownFocus) -> some View {
        let isFocused = focus == type
        return Button {
            withAnimation(.easeInOut(duration: 0.1)) { focus = type }
            WKInterfaceDevice.current().play(.click)
        } label: {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(WatchTheme.cardBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isFocused ? WatchTheme.cyan : Color.clear, lineWidth: 2))
        }.buttonStyle(.plain)
    }
    
    private var optionsMenu: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set options")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
            
            Button {
                viewModel.addSetToExercise(at: exerciseIndex)
                changeSet(by: 1)
            } label: {
                Text("Add Set")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(WatchTheme.buttonGray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }.buttonStyle(.plain)
            
            Button(role: .destructive) {
                Task {
                    await viewModel.removeSet(exerciseIndex: exerciseIndex, setIndex: currentSetIndex)
                    if currentSetIndex > 1 { changeSet(by: -1) } else { loadDataForCurrentSet() }
                }
            } label: {
                Text("Delete Set")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(WatchTheme.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }.buttonStyle(.plain)
            
            Text("Exercise options")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
                .padding(.top, 8)
            
            Button(role: .destructive) {
                Task {
                    await viewModel.removeExercise(at: exerciseIndex)
                    dismiss()
                }
            } label: {
                Text("Delete Exercise")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(WatchTheme.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }.buttonStyle(.plain)
        }
    }
    
    private func setupInitialSet() {
        let sets = viewModel.exercises[exerciseIndex].setsList ?? []
        if let firstUncompleted = sets.first(where: { !$0.isCompleted }) {
            currentSetIndex = firstUncompleted.index
        } else {
            currentSetIndex = sets.isEmpty ? 1 : sets.count
        }
        loadDataForCurrentSet()
    }
    
    private func changeSet(by amount: Int) {
        let exercise = viewModel.exercises[exerciseIndex]
        let targetSets = exercise.sets ?? 3
        let actualSets = exercise.setsList?.count ?? 0
        let maxAllowedSets = max(1, max(targetSets, actualSets))
        
        let newIndex = currentSetIndex + amount
        
        if newIndex < 1 || newIndex > maxAllowedSets { return }
        
        WKInterfaceDevice.current().play(.click)
        withAnimation(.easeInOut(duration: 0.2)) {
            currentSetIndex = newIndex
            loadDataForCurrentSet()
        }
    }
    
    private func loadDataForCurrentSet() {
        let sets = viewModel.exercises[exerciseIndex].setsList ?? []
        if let existingSet = sets.first(where: { $0.index == currentSetIndex }) {
            weight = existingSet.weight ?? 0.0
            reps = Double(existingSet.reps ?? 0)
            isCurrentSetCompleted = existingSet.isCompleted
        } else {
            if let prevSet = sets.first(where: { $0.index == currentSetIndex - 1 }) {
                weight = prevSet.weight ?? 0.0
                reps = Double(prevSet.reps ?? 0)
            } else {
                weight = 0.0
                reps = 0.0
            }
            isCurrentSetCompleted = false
        }
    }
}

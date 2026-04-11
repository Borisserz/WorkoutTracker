// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/EffortInputView.swift
// ============================================================

internal import SwiftUI

// MARK: - RPE Data Model
fileprivate struct RPEData {
    let value: Int
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let color: Color
    
    static func get(for value: Int) -> RPEData {
        switch value {
        case 1...4:
            return RPEData(value: value, title: "Light Effort", description: "Could easily do 5+ more reps", color: .blue)
        case 5...6:
            return RPEData(value: value, title: "Moderate Effort", description: "Could definitely do 4 more reps", color: .green)
        case 7:
            return RPEData(value: value, title: "Hard Effort", description: "Could do 3 more reps", color: .yellow)
        case 8:
            return RPEData(value: value, title: "Very Hard Effort", description: "Could do 2 more reps", color: .orange)
        case 9:
            return RPEData(value: value, title: "Intense Effort", description: "Could do 1 more rep", color: .red)
        case 10:
            return RPEData(value: value, title: "Maximal Effort", description: "Absolute failure. 0 reps in reserve", color: .purple)
        default:
            return RPEData(value: 5, title: "Moderate Effort", description: "Could definitely do 4 more reps", color: .green)
        }
    }
}

// MARK: - Main View
struct EffortInputView: View {
    @Binding var effort: Int
    @Environment(\.dismiss) var dismiss
    @Environment(TutorialManager.self) var tutorialManager
    
    // Локальное состояние для анимаций до сохранения
    @State private var localEffort: Int = 5
    
    private var currentRPE: RPEData {
        RPEData.get(for: localEffort)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Text(LocalizedStringKey("Log Exercise Effort"))
                    .font(.headline)
                    .padding(.top, 8)
                
                Text(LocalizedStringKey("How hard was this exercise overall?"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)
            
            // Giant Number & Description
            VStack(spacing: 12) {
                Text("\(localEffort)")
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundColor(currentRPE.color)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: localEffort)
                
                VStack(spacing: 4) {
                    Text(currentRPE.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .animation(.none, value: localEffort) // Отключаем кроссфейд для четкости
                    
                    Text(currentRPE.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .animation(.none, value: localEffort)
                }
            }
            .frame(height: 180)
            
            Spacer(minLength: 20)
            
            // Horizontal Picker
            horizontalPicker
            
            Spacer(minLength: 30)
            
            // Done Button
            Button {
                saveAndDismiss()
            } label: {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey("Done"))
                    Image(systemName: "checkmark")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(currentRPE.color)
                .cornerRadius(16)
                .shadow(color: currentRPE.color.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .spotlight(
                step: .explainEffort,
                manager: tutorialManager,
                text: "Select your RPE and tap Done. This powers your AI analytics!",
                alignment: .top,
                yOffset: -20
            )
        }
        .onAppear {
            localEffort = effort > 0 ? effort : 5
        }
        .presentationDetents([.height(500)]) // Идеальная высота для этого контента
        .presentationDragIndicator(.hidden) // Мы отрисовали свой кастомный индикатор выше
    }
    
    // MARK: - Components
    
    private var horizontalPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Пустые отступы по краям, чтобы крайние элементы могли быть по центру
                    Spacer().frame(width: 20)
                    
                    ForEach(1...10, id: \.self) { value in
                        let isSelected = value == localEffort
                        
                        Button {
                            selectEffort(value, proxy: proxy)
                        } label: {
                            Text("\(value)")
                                .font(.title3)
                                .fontWeight(isSelected ? .bold : .medium)
                                .frame(width: 50, height: 50)
                                .background(isSelected ? currentRPE.color : Color(UIColor.secondarySystemBackground))
                                .foregroundColor(isSelected ? .white : .primary)
                                .clipShape(Circle())
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .id(value)
                    }
                    
                    Spacer().frame(width: 20)
                }
                .padding(.vertical, 10)
            }
            .onAppear {
                // При открытии центрируем на текущем значении
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo(localEffort, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func selectEffort(_ value: Int, proxy: ScrollViewProxy) {
        if localEffort != value {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            
            localEffort = value
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                proxy.scrollTo(value, anchor: .center)
            }
        }
    }
    
    private func saveAndDismiss() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        effort = localEffort
        dismiss()
        
        if tutorialManager.currentStep == .explainEffort {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                tutorialManager.setStep(.highlightChart)
            }
        }
    }
}

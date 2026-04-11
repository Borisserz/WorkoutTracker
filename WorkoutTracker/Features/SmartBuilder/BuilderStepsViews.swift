//
//  BuilderStepsViews.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 7.04.26.
//

// ============================================================
// FILE: WorkoutTracker/Features/SmartBuilder/BuilderStepsViews.swift
// ============================================================

internal import SwiftUI

// MARK: - Step 1: Muscle Selection
struct MuscleSelectionView: View {
    @Bindable var vm: SmartGeneratorViewModel
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("What are we hitting today?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(vm.availableMuscles, id: \.self) { muscle in
                            let isSelected = vm.targetMuscles.contains(muscle)
                            
                            Button {
                                vm.toggleMuscle(muscle)
                            } label: {
                                VStack {
                                    Image(systemName: icon(for: muscle))
                                        .font(.title)
                                        .foregroundColor(isSelected ? themeManager.current.lightHighlight : .secondary)
                                        .padding(.bottom, 4)
                                    
                                    Text(LocalizedStringKey(muscle))
                                        .font(.headline)
                                        .foregroundColor(isSelected ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(
                                    ZStack {
                                        themeManager.current.surface
                                        if isSelected {
                                            themeManager.current.primaryAccent.opacity(0.2)
                                        }
                                    }
                                )
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isSelected ? themeManager.current.lightHighlight : Color.clear, lineWidth: 2)
                                )
                                .shadow(color: isSelected ? themeManager.current.lightHighlight.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(isSelected ? 1.02 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120)
                }
            }
            
            // Continue Button
            Button {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
                vm.path.append("Settings")
            } label: {
                Text("Next Step")
                    .font(.headline).bold()
                    .foregroundColor(themeManager.current.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(vm.targetMuscles.isEmpty ? Color.gray : themeManager.current.primaryAccent)
                    .clipShape(Capsule())
                    .shadow(color: vm.targetMuscles.isEmpty ? .clear : themeManager.current.primaryAccent.opacity(0.4), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .disabled(vm.targetMuscles.isEmpty)
            .animation(.easeInOut, value: vm.targetMuscles.isEmpty)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func icon(for muscle: String) -> String {
        switch muscle {
        case "Chest": return "shield.fill"
        case "Back": return "arrow.up.and.down.and.sparkles"
        case "Legs": return "figure.walk"
        case "Shoulders": return "figure.arms.open"
        case "Arms": return "hand.raised.fill"
        case "Core": return "bolt.shield.fill"
        case "Cardio": return "heart.fill"
        default: return "dumbbell.fill"
        }
    }
}
// MARK: - Step 2: Settings
struct GeneratorSettingsView: View {
    @Bindable var vm: SmartGeneratorViewModel
    @Environment(ThemeManager.self) private var themeManager
    
    // ✅ ИСПРАВЛЕНИЕ 1: Добавляем Environment для доступа к истории твоих весов
    @Environment(DashboardViewModel.self) private var dashboard
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Form {
                Section(header: Text("Duration")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(Int(vm.durationMinutes)) minutes")
                                .font(.title2).bold()
                                .foregroundColor(themeManager.current.lightHighlight)
                            Spacer()
                        }
                        Slider(value: $vm.durationMinutes, in: 15...120, step: 5)
                            .tint(themeManager.current.lightHighlight)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Experience Level")) {
                    Picker("Difficulty", selection: $vm.difficulty) {
                        ForEach(WorkoutDifficulty.allCases, id: \.self) { diff in
                            Text(LocalizedStringKey(diff.rawValue)).tag(diff)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Available Equipment")) {
                    Picker("Equipment", selection: $vm.equipment) {
                        ForEach(WorkoutEquipment.allCases, id: \.self) { eq in
                            Text(LocalizedStringKey(eq.rawValue)).tag(eq)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.bottom, 100)
            
            Button {
                // ✅ ИСПРАВЛЕНИЕ 2: Передаем историю твоих упражнений в алгоритм!
                Task { await vm.generateWorkout(historyCache: dashboard.lastPerformancesCache) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                    Text("Generate Routine")
                        .font(.headline).bold()
                }
                .foregroundColor(themeManager.current.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    themeManager.current.primaryGradient
                )
                .clipShape(Capsule())
                .shadow(color: themeManager.current.lightHighlight.opacity(0.4), radius: 15, x: 0, y: 8)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Parameters")
        .navigationBarTitleDisplayMode(.inline)
    }
}

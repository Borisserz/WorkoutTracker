// ============================================================
// FILE: WorkoutTracker/Features/SmartBuilder/BuilderStepsViews.swift
// ============================================================

internal import SwiftUI

// MARK: - Step 1: Muscle Selection
struct MuscleSelectionView: View {
    @Bindable var vm: SmartGeneratorViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 👈 АДАПТАЦИЯ ФОНА СТРАНИЦЫ
            (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Что сегодня тренируем?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black) // 👈 АДАПТАЦИЯ
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
                                                                    .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .secondary : themeManager.current.primaryAccent)) // 👈 ИСПРАВЛЕНИЕ ИКОНКИ
                                                                    .padding(.bottom, 4)
                                                                
                                                                Text(LocalizedStringKey(muscle))
                                                                    .font(.headline)
                                                                    .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .primary : .black))
                                                            }
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 24)
                                                            .background(
                                                                ZStack {
                                                                    (colorScheme == .dark ? themeManager.current.surface : Color.white)
                                                                    if isSelected {
                                                                        themeManager.current.primaryAccent // 👈 ИСПРАВЛЕНИЕ: Сплошной синий цвет при выборе
                                                                    }
                                                                }
                                                            )
                                                            .cornerRadius(20)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 20)
                                                                    .stroke(isSelected ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.clear : Color.black.opacity(0.05)), lineWidth: isSelected ? 0 : 1)
                                                            )
                                                            .shadow(color: isSelected ? themeManager.current.primaryAccent.opacity(0.4) : .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 10, x: 0, y: 5)
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
                Text("Следующий шаг")
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
    @Environment(\.colorScheme) private var colorScheme // 👈 АДАПТАЦИЯ
    @Environment(DashboardViewModel.self) private var dashboard
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 👈 АДАПТАЦИЯ ФОНА ПОД ФОРМОЙ
            (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                .ignoresSafeArea()
            
            Form {
                Section(header: Text("Продолжительность")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(Int(vm.durationMinutes)) минут")
                                .font(.title2).bold()
                                .foregroundColor(colorScheme == .dark ? themeManager.current.lightHighlight : .blue) // 👈 АДАПТАЦИЯ ЦВЕТА
                            Spacer()
                        }
                        Slider(value: $vm.durationMinutes, in: 15...120, step: 5)
                            .tint(colorScheme == .dark ? themeManager.current.lightHighlight : .blue)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Уровень опыта")) {
                    Picker("Уровень", selection: $vm.difficulty) {
                        ForEach(WorkoutDifficulty.allCases, id: \.self) { diff in
                            Text(LocalizedStringKey(diff.rawValue)).tag(diff)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Доступное оборудование")) {
                    Picker("Оборудование", selection: $vm.equipment) {
                        ForEach(WorkoutEquipment.allCases, id: \.self) { eq in
                            Text(LocalizedStringKey(eq.rawValue)).tag(eq)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.bottom, 100)
            
            Button {
                Task { await vm.generateWorkout(historyCache: dashboard.lastPerformancesCache) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                    Text("Сгенерировать рутину")
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
        .navigationTitle("Параметры")
        .navigationBarTitleDisplayMode(.inline)
    }
}

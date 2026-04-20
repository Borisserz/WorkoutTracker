// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/AdvancedFiltersSheet.swift
// ============================================================

internal import SwiftUI

struct AdvancedFiltersSheet: View {
    @Bindable var filterState: ExerciseFilterState
    let resultsCount: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 ДОБАВЛЕНО
    
    private let equipmentList = ["barbell", "dumbbell1", "machine", "cable", "bodyweight", "kettlebell", "bands"]
    private let mechanicsList = ["compound", "isolation"]
    private let levelsList = ["beginner", "intermediate", "expert"]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Адаптивный фон темы
                (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        AdvancedFilterSectionView(title: "Уровень опыта", items: levelsList, selectedItems: $filterState.selectedLevel, filterState: filterState)
                        AdvancedFilterSectionView(title: "Механика", items: mechanicsList, selectedItems: $filterState.selectedMechanic, filterState: filterState)
                        AdvancedFilterSectionView(title: "Оборудование", items: equipmentList, selectedItems: $filterState.selectedEquipment, filterState: filterState)
                        
                        Spacer(minLength: 100) // Отступ под плавающую кнопку
                    }
                    .padding(.vertical, 24)
                }
                
                // Элегантная парящая кнопка (Floating Action Button)
                Button {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    dismiss()
                } label: {
                    Text(LocalizedStringKey("Показать \(resultsCount) упражнений"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.current.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.current.primaryAccent) // Ровный неоновый цвет вместо агрессивного градиента
                        .clipShape(Capsule()) // Делаем ее круглой (капсулой)
                        .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 32) // Отступы по краям, чтобы кнопка не давила
                .padding(.bottom, 20)
                .background(
                    // Адаптивный градиент для затемнения под кнопкой
                    LinearGradient(colors: [colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground), (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground)).opacity(0)], startPoint: .bottom, endPoint: .top)
                        .ignoresSafeArea()
                )
            }
            .navigationTitle(LocalizedStringKey("Дополнительно"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Очистить")) {
                        let gen = UIImpactFeedbackGenerator(style: .rigid)
                        gen.impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { filterState.clearAdvancedFilters() }
                    }
                    .disabled(filterState.activeAdvancedFiltersCount == 0)
                    .foregroundColor(filterState.activeAdvancedFiltersCount == 0 ? .gray : .red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Готово")) { dismiss() }.fontWeight(.bold).foregroundColor(themeManager.current.primaryAccent)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }
}

struct AdvancedFilterSectionView: View {
    let title: String
    let items: [String]
    @Binding var selectedItems: Set<String>
    var filterState: ExerciseFilterState
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 ДОБАВЛЕНО
    
    private func displayString(for item: String) -> String {
        if item == "dumbbell1" { return "Dumbbell" }
        return item.capitalized
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? themeManager.current.secondaryText : .secondary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Spacer().frame(width: 10)
                    ForEach(items, id: \.self) { item in
                        let isSelected = selectedItems.contains(item)
                        let buttonTitle = displayString(for: item)
                        
                        Button {
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                filterState.toggle(item: item, in: &selectedItems)
                            }
                        } label: {
                            Text(LocalizedStringKey(buttonTitle))
                                .font(.subheadline)
                                .fontWeight(isSelected ? .bold : .medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                // Адаптивный стеклянный дизайн чипсов
                                .background(isSelected ? themeManager.current.primaryAccent.opacity(colorScheme == .dark ? 0.15 : 1.0) : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)))
                                .foregroundColor(isSelected ? (colorScheme == .dark ? themeManager.current.primaryAccent : .white) : (colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8)))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer().frame(width: 10)
                }
            }
        }
    }
}

internal import SwiftUI

struct AdvancedFiltersSheet: View {
    @Bindable var filterState: ExerciseFilterState
    let resultsCount: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    private let equipmentList = ["barbell", "dumbbell1", "machine", "cable", "bodyweight", "kettlebell", "bands"]
    private let mechanicsList = ["compound", "isolation"]
    private let levelsList = ["beginner", "intermediate", "expert"]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        
                        AdvancedFilterSectionView(title: "Experience Level", items: levelsList, selectedItems: $filterState.selectedLevel, filterState: filterState)
                        AdvancedFilterSectionView(title: "Mechanic", items: mechanicsList, selectedItems: $filterState.selectedMechanic, filterState: filterState)
                        AdvancedFilterSectionView(title: "Equipment", items: equipmentList, selectedItems: $filterState.selectedEquipment, filterState: filterState)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical, 24)
                }
                
                Button {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    dismiss()
                } label: {
                    Text(LocalizedStringKey("Show \(resultsCount) Exercises"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.current.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.current.primaryGradient)
                        .cornerRadius(16)
                        .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .background(LinearGradient(colors: [Color(UIColor.systemGroupedBackground), Color(UIColor.systemGroupedBackground).opacity(0)], startPoint: .bottom, endPoint: .top).ignoresSafeArea())
            }
            .navigationTitle(LocalizedStringKey("Advanced Filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Clear")) {
                        let gen = UIImpactFeedbackGenerator(style: .rigid)
                        gen.impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { filterState.clearAdvancedFilters() }
                    }
                    .disabled(filterState.activeAdvancedFiltersCount == 0)
                    .foregroundColor(filterState.activeAdvancedFiltersCount == 0 ? .gray : .red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Done")) { dismiss() }.fontWeight(.bold)
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
    
    // Вспомогательная функция для красивого отображения ключей
    private func displayString(for item: String) -> String {
        if item == "dumbbell1" { return "Dumbbell" }
        return item.capitalized
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundColor(themeManager.current.secondaryText)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Spacer().frame(width: 10)
                    ForEach(items, id: \.self) { item in
                        let isSelected = selectedItems.contains(item)
                        let buttonTitle = displayString(for: item) // 👈 Получаем чистое имя
                        
                        Button {
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                filterState.toggle(item: item, in: &selectedItems)
                            }
                        } label: {
                            Text(LocalizedStringKey(buttonTitle)) // 👈 Переводим чистое имя
                                .font(.subheadline)
                                .fontWeight(isSelected ? .bold : .medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(isSelected ? themeManager.current.primaryAccent : themeManager.current.surface)
                                .foregroundColor(isSelected ? .white : .primary)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? themeManager.current.primaryAccent : Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer().frame(width: 10)
                }
            }
        }
    }
}

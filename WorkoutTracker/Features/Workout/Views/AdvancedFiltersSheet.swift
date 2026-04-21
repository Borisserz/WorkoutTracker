

internal import SwiftUI

struct AdvancedFiltersSheet: View {
    @Bindable var filterState: ExerciseFilterState
    let resultsCount: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme 

    private let equipmentList = ["barbell", "dumbbell1", "machine", "cable", "bodyweight", "kettlebell", "bands"]
    private let mechanicsList = ["compound", "isolation"]
    private let levelsList = ["beginner", "intermediate", "expert"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()

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
                    Text(LocalizedStringKey("Show \(resultsCount) exercises"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.current.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.current.primaryAccent) 
                        .clipShape(Capsule()) 
                        .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 32) 
                .padding(.bottom, 20)
                .background(

                    LinearGradient(colors: [colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground), (colorScheme == .dark ? themeManager.current.background : Color(UIColor.systemGroupedBackground)).opacity(0)], startPoint: .bottom, endPoint: .top)
                        .ignoresSafeArea()
                )
            }
            .navigationTitle(LocalizedStringKey("Advanced"))
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
                    Button(LocalizedStringKey("Done")) { dismiss() }.fontWeight(.bold).foregroundColor(themeManager.current.primaryAccent)
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
    @Environment(\.colorScheme) private var colorScheme 

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

                                .background(isSelected ? themeManager.current.primaryAccent.opacity(colorScheme == .dark ? 0.15 : 1.0) : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.white))

                                .foregroundColor(isSelected ? (colorScheme == .dark ? themeManager.current.primaryAccent : .white) : (colorScheme == .dark ? .white.opacity(0.8) : .black))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()

                                        .stroke(isSelected ? themeManager.current.primaryAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.2)), lineWidth: 1)
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

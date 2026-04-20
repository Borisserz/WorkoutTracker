// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/PremiumExerciseSearchBar.swift
// ============================================================

internal import SwiftUI

struct PremiumExerciseSearchBar: View {
    @Bindable var filterState: ExerciseFilterState
    var onFilterTap: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme // 👈 ДОБАВЛЕНО
    
    var body: some View {
        HStack(spacing: 12) {
            // Стеклянная поисковая строка
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                    .font(.body)
                
                TextField(LocalizedStringKey("Поиск упражнений..."), text: $filterState.searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    .tint(themeManager.current.primaryAccent)
                    .autocorrectionDisabled()
                
                if !filterState.searchText.isEmpty {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            filterState.searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(12)
            .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground)), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, x: 0, y: 2)
            
            // Кнопка расширенных фильтров
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onFilterTap()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            filterState.activeAdvancedFiltersCount > 0
                            ? themeManager.current.primaryAccent
                            : (colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.6))
                        )
                    
                    if filterState.activeAdvancedFiltersCount > 0 {
                        Text("\(filterState.activeAdvancedFiltersCount)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(themeManager.current.surface, lineWidth: 2))
                            .offset(x: 6, y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(12)
                .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground)), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(filterState.activeAdvancedFiltersCount > 0 ? themeManager.current.primaryAccent.opacity(0.5) : (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

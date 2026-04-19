internal import SwiftUI

struct PremiumExerciseSearchBar: View {
    @Bindable var filterState: ExerciseFilterState
    var onFilterTap: () -> Void
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Стеклянная поисковая строка
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.body)
                
                TextField(LocalizedStringKey("Поиск упражнений..."), text: $filterState.searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.white)
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
                            .foregroundColor(.white.opacity(0.5))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
            
            // Кнопка расширенных фильтров (Теперь с четким фоном)
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
                            : Color.white.opacity(0.8)
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
                .padding(12) // Размер подгоняем под высоту поиска
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(filterState.activeAdvancedFiltersCount > 0 ? themeManager.current.primaryAccent.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

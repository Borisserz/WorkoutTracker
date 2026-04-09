// ============================================================
// FILE: WorkoutTracker/Features/Workout/Views/HistoryView.swift
// ============================================================

internal import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(UnitsManager.self) var unitsManager
    @Environment(DashboardViewModel.self) var dashboardViewModel
    
    @State private var searchDebouncer = SearchDebouncer()
    @State private var selectedFilter: WorkoutView.FilterPeriod = .all
    @State private var sortOption: WorkoutView.SortOption = .dateDescending
    @State private var showFavoritesOnly = false
    @State private var listViewModel = WorkoutListViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                List {
                    // 1. Секция: Компактная статистика
                    Section {
                        statsSection
                    }
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    
                    // 2. Секция: Прилипающая шапка и Список
                    Section {
                        DynamicWorkoutListView(
                            searchText: searchDebouncer.debouncedText,
                            filter: selectedFilter,
                            sort: sortOption,
                            favoritesOnly: showFavoritesOnly,
                            listViewModel: listViewModel,
                            onFirstWorkoutLoaded: nil
                        )
                    } header: {
                        stickyControlBar
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(LocalizedStringKey("History"))
        }
    }
    
    // MARK: - View Components
    
    private var statsSection: some View {
            // Вычисляем тонны
            let tons = Double(listViewModel.calculatedAvgVolume) / 1000.0
            let formattedTons = LocalizationHelper.shared.formatTwoDecimals(tons)
            
            return HStack(spacing: 12) {
                CompactStatCard(
                    title: "Avg Duration",
                    value: "\(listViewModel.calculatedAvgDuration)",
                    unit: "min",
                    icon: "stopwatch.fill",
                    colors: [.purple, .indigo]
                )
                
                CompactStatCard(
                    title: "Avg Volume",
                    value: formattedTons,
                    unit: "tons", // Жестко задаем тонны
                    icon: "scalemass.fill",
                    colors: [.cyan, .blue]
                )
            }
        }
    
    private var stickyControlBar: some View {
            VStack(spacing: 12) {
                PremiumSearchBar(debouncer: searchDebouncer)
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: 6)
                        
                        // Кнопка: Избранное
                        Button {
                            triggerFeedback()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showFavoritesOnly.toggle()
                            }
                        } label: {
                            HistoryFilterChipView(
                                title: "Favorites",
                                icon: "star.fill",
                                isSelected: showFavoritesOnly,
                                activeColor: .yellow
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Меню: Сортировка
                        Menu {
                            ForEach(WorkoutView.SortOption.allCases, id: \.self) { option in
                                Button {
                                    triggerFeedback()
                                    sortOption = option
                                } label: {
                                    Label(LocalizedStringKey(option.rawValue), systemImage: sortIcon(for: option))
                                }
                            }
                        } label: {
                            // Используем только View, без Button внутри, чтобы Menu не ломало стили
                            HistoryFilterChipView(
                                title: LocalizedStringKey(sortOption.rawValue),
                                icon: "arrow.up.arrow.down",
                                isSelected: false, // Делаем серым/белым как обычный фильтр
                                activeColor: .clear
                            )
                        }
                        
                        // Кнопки: Periodы
                        ForEach(WorkoutView.FilterPeriod.allCases, id: \.self) { period in
                            Button {
                                triggerFeedback()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedFilter = period
                                }
                            } label: {
                                HistoryFilterChipView(
                                    title: LocalizedStringKey(period.rawValue),
                                    icon: nil,
                                    isSelected: selectedFilter == period,
                                    activeColor: .blue
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer().frame(width: 6)
                    }
                    .padding(.bottom, 12)
                }
            }
            .padding(.top, 12)
            .background(.ultraThinMaterial) // Эффект Glassmorphism
            .padding(.horizontal, -20) // Растягиваем на всю ширину списка
        }
    private func triggerFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func sortIcon(for option: WorkoutView.SortOption) -> String {
        switch option {
        case .dateDescending, .dateAscending: return "calendar"
        case .durationDescending, .durationAscending: return "stopwatch"
        case .effortDescending, .effortAscending: return "flame"
        }
    }
}

// MARK: - Custom UI Components

struct CompactStatCard: View {
    let title: LocalizedStringKey
    let value: String
    let unit: LocalizedStringKey
    let icon: String
    let colors: [Color]
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                    .opacity(0.15)
                Image(systemName: icon)
                    .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

struct PremiumSearchBar: View {
    @Bindable var debouncer: SearchDebouncer
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(LocalizedStringKey("Search workouts..."), text: $debouncer.inputText)
                .textFieldStyle(.plain)
                .font(.subheadline)
            
            if !debouncer.inputText.isEmpty {
                Button {
                    withAnimation { debouncer.inputText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
}
struct HistoryFilterChipView: View {
    let title: LocalizedStringKey
    let icon: String?
    let isSelected: Bool
    let activeColor: Color
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
        }
        // Цвет текста: если выбран — акцентный (синий/желтый), иначе стандартный черный/белый
        .foregroundColor(isSelected ? activeColor : .primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // Фон всегда делаем плотным, как у остальных кнопок, чтобы избежать прозрачности при скролле
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                // Если выбран — выделяем цветной рамкой чуть большей толщины
                .stroke(isSelected ? activeColor : Color.gray.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

//
//  WorkoutView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

internal import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @StateObject private var unitsManager = UnitsManager.shared
    
    // Состояние для открытия шторки с советом
    @State private var showImbalanceInfo = false
    
    // Навигация и модальные окна
    @State private var showAddWorkout = false
    @State private var navigateToNewWorkout = false
    
    // Поиск и фильтры
    @State private var searchText = ""
    @State private var selectedFilter: FilterPeriod = .all
    @State private var sortOption: SortOption = .dateDescending
    
    // Удаление с предупреждением
    @State private var showDeleteAlert = false
    @State private var workoutsToDelete: [Workout] = []
    
    enum FilterPeriod: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case week = "Last Week"
        case month = "Last Month"
        case threeMonths = "Last 3 Months"
        case year = "Last Year"
    }
    
    enum SortOption: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case durationDescending = "Longest First"
        case durationAscending = "Shortest First"
        case effortDescending = "Highest Effort"
        case effortAscending = "Lowest Effort"
    }
    
    // Отфильтрованные и отсортированные тренировки
    var filteredWorkouts: [Workout] {
        var workouts = viewModel.workouts
        
        // Фильтр по периоду
        let calendar = Calendar.current
        let now = Date()
        switch selectedFilter {
        case .all:
            break
        case .favorites:
            workouts = workouts.filter { $0.isFavorite }
        case .week:
            if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) {
                workouts = workouts.filter { $0.date >= weekAgo }
            }
        case .month:
            if let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) {
                workouts = workouts.filter { $0.date >= monthAgo }
            }
        case .threeMonths:
            if let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) {
                workouts = workouts.filter { $0.date >= threeMonthsAgo }
            }
        case .year:
            if let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) {
                workouts = workouts.filter { $0.date >= yearAgo }
            }
        }
        
        // Поиск по названию
        if !searchText.isEmpty {
            workouts = workouts.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Сортировка
        switch sortOption {
        case .dateDescending:
            workouts.sort { $0.date > $1.date }
        case .dateAscending:
            workouts.sort { $0.date < $1.date }
        case .durationDescending:
            workouts.sort { $0.duration > $1.duration }
        case .durationAscending:
            workouts.sort { $0.duration < $1.duration }
        case .effortDescending:
            workouts.sort { $0.effortPercentage > $1.effortPercentage }
        case .effortAscending:
            workouts.sort { $0.effortPercentage < $1.effortPercentage }
        }
        
        return workouts
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("History"))
                // --- НАВИГАЦИЯ ---
                .navigationDestination(isPresented: $navigateToNewWorkout) {
                    if !viewModel.workouts.isEmpty {
                        WorkoutDetailView(workout: $viewModel.workouts[0])
                    }
                }
                // --- ВЕРХНЯЯ ПАНЕЛЬ (TOOLBAR) ---
                .toolbar {
                    // 1. Кнопка "Править" (справа)
                    if !viewModel.workouts.isEmpty {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            EditButton()
                        }
                    }
                    
                    // 2. КНОПКА ДИСБАЛАНСА
                    // Показываем ТОЛЬКО если есть рекомендация (не nil)
                    if viewModel.getImbalanceRecommendation() != nil {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showImbalanceInfo = true
                            } label: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .symbolRenderingMode(.multicolor) // Желтый треугольник с восклицательным знаком
                                    .font(.title3)
                            }
                        }
                    }
                }
                // --- ВСПЛЫВАЮЩИЕ ШТОРКИ (SHEETS) ---
                .sheet(isPresented: $showAddWorkout) {
                    AddWorkoutView(workouts: $viewModel.workouts, onWorkoutCreated: {
                        navigateToNewWorkout = true
                    })
                }
                .sheet(isPresented: $showImbalanceInfo) {
                    if let advice = viewModel.getImbalanceRecommendation() {
                        ImbalanceDetailSheet(advice: advice)
                            .presentationDetents([.fraction(0.35)]) // Шторка занимает 35% экрана снизу
                            .presentationDragIndicator(.visible)
                    }
                }
                .alert(LocalizedStringKey("Delete Workout?"), isPresented: $showDeleteAlert) {
                    Button(LocalizedStringKey("Delete"), role: .destructive) {
                        deleteWorkouts()
                    }
                    Button(LocalizedStringKey("Cancel"), role: .cancel) {
                        workoutsToDelete = []
                    }
                } message: {
                    if workoutsToDelete.count == 1 {
                        Text(LocalizedStringKey("Are you sure you want to delete '\(workoutsToDelete.first?.title ?? "")'? This action cannot be undone."))
                    } else {
                        Text(LocalizedStringKey("Are you sure you want to delete \(workoutsToDelete.count) workouts? This action cannot be undone."))
                    }
                }
        }
    }
    
    // Выносим содержимое в отдельную переменную
    @ViewBuilder
    var content: some View {
        if viewModel.workouts.isEmpty {
            emptyState
        } else {
            List {
                // Кнопка "Начать тренировку" - на всю ширину
                Section {
                    Button {
                        showAddWorkout = true
                    } label: {
                        Text(LocalizedStringKey("Start Workout"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                
                // Статистика вверху
                Section {
                    statsSection
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                // Поиск и фильтры
                Section {
                    searchAndFiltersSection
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                // Список тренировок
                Section {
                    if filteredWorkouts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.3))
                            Text(LocalizedStringKey("No workouts found"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(LocalizedStringKey("Try adjusting your search or filters"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(filteredWorkouts) { workout in
                            ZStack {
                                NavigationLink(destination: WorkoutDetailView(workout: Binding(
                                    get: { workout },
                                    set: { newValue in
                                        if let index = viewModel.workouts.firstIndex(where: { $0.id == workout.id }) {
                                            viewModel.workouts[index] = newValue
                                        }
                                    }
                                ))) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                WorkoutRow(workout: workout)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onDelete { indexSet in
                            let toDelete = indexSet.map { filteredWorkouts[$0] }
                            workoutsToDelete = toDelete
                            showDeleteAlert = true
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    // Секция статистики
    private var statsSection: some View {
        let totalWorkouts = viewModel.workouts.count
        let avgDuration = viewModel.workouts.isEmpty ? 0 : viewModel.workouts.reduce(0) { $0 + $1.duration } / viewModel.workouts.count
        let totalVolume = viewModel.workouts.reduce(0.0) { $0 + $1.exercises.reduce(0.0) { $0 + $1.computedVolume } }
        let avgVolume = totalWorkouts > 0 ? Int(totalVolume / Double(totalWorkouts)) : 0
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    title: LocalizedStringKey("Avg Duration"),
                    value: "\(avgDuration)",
                    subtitle: LocalizedStringKey("min"),
                    icon: "stopwatch"
                )
                
                StatCard(
                    title: LocalizedStringKey("Avg Volume"),
                    value: "\(Int(unitsManager.convertFromKilograms(Double(avgVolume))))",
                    subtitle: LocalizedStringKey(unitsManager.weightUnitString()),
                    icon: "scalemass"
                )
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }
    
    // Секция поиска и фильтров
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Поиск
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(LocalizedStringKey("Search workouts..."), text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Фильтры и сортировка
            HStack(spacing: 12) {
                Menu {
                    ForEach(FilterPeriod.allCases, id: \.self) { period in
                        Button(LocalizedStringKey(period.rawValue)) {
                            selectedFilter = period
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                        Text(LocalizedStringKey(selectedFilter.rawValue))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            sortOption = option
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortOption.rawValue)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    // Экран, когда пусто
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.3))
            Text(LocalizedStringKey("No workouts yet"))
                .font(.title2)
                .bold()
                .foregroundColor(.secondary)
            Text(LocalizedStringKey("Start your first workout from the Overview tab!"))
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    
    func deleteWorkouts() {
        withAnimation {
            for workout in workoutsToDelete {
                if let index = viewModel.workouts.firstIndex(where: { $0.id == workout.id }) {
                    viewModel.workouts.remove(at: index)
                }
            }
            workoutsToDelete = []
        }
    }
}

// --- НОВАЯ ВЬЮХА ДЛЯ ВСПЛЫВАЮЩЕГО ОКНА ---
struct ImbalanceDetailSheet: View {
    let advice: (title: String, message: String)
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Иконка
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
                .padding(.top, 20)
            
            VStack(spacing: 8) {
                Text(advice.title)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                
                Text(advice.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(LocalizedStringKey("Got it, Coach!")) {
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 20)
        }
        .padding()
    }
}

// --- ДИЗАЙН ЯЧЕЙКИ ТРЕНИРОВКИ ---
struct WorkoutRow: View {
    let workout: Workout
    
    func effortColor(percentage: Int) -> Color {
        if percentage > 80 { return .red }
        if percentage > 50 { return .orange }
        return .green
    }
    
    var body: some View {
        HStack {
            Image(systemName: workout.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(LocalizedStringKey("\(workout.duration) min"))
                    .font(.subheadline)
                    .bold()
                
                Text(LocalizedStringKey("Effort: \(workout.effortPercentage)%"))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(effortColor(percentage: workout.effortPercentage).opacity(0.2))
                    .foregroundColor(effortColor(percentage: workout.effortPercentage))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Карточка статистики
struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: LocalizedStringKey
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    WorkoutView()
        .environmentObject(WorkoutViewModel())
}

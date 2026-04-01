//
//  WorkoutView.swift
//  WorkoutTracker
//

internal import SwiftUI
import SwiftData
import UIKit

// MARK: - Main View

struct WorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutViewModel.self) var viewModel
@Environment(UnitsManager.self) var unitsManager
    
    // ОПТИМИЗАЦИЯ: Грузим только последние 30 тренировок для проверки на пустоту и анализа дисбаланса (защита от OOM)
    @Query(sort: \Workout.date, order: .reverse) private var recentWorkoutsForImbalance: [Workout]
    
    @State private var showImbalanceInfo = false
    @State private var showAddWorkout = false
    @State private var navigateToNewWorkout = false
    
    @State private var searchText = ""
    @State private var selectedFilter: FilterPeriod = .all
    @State private var sortOption: SortOption = .dateDescending
    @State private var showFavoritesOnly = false
    
    @State private var calculatedAvgDuration: Int = 0
    @State private var calculatedAvgVolume: Int = 0
    
    enum FilterPeriod: String, CaseIterable {
        case all = "All Time"
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
    
    init() {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 30 // Для дисбаланса нужны только свежие данные
        _recentWorkoutsForImbalance = Query(descriptor)
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("History"))
                .navigationDestination(isPresented: $navigateToNewWorkout) {
                    // Переход к новой тренировке
                    if let first = recentWorkoutsForImbalance.first {
                        WorkoutDetailView(workout: first)
                    }
                }
                .toolbar {
                    if !recentWorkoutsForImbalance.isEmpty {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            EditButton()
                        }
                    }
                    
                    if let advice = AnalyticsManager.getImbalanceRecommendation(recentWorkouts: recentWorkoutsForImbalance) {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showImbalanceInfo = true
                            } label: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .symbolRenderingMode(.multicolor)
                                    .font(.title3)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showAddWorkout) {
                    AddWorkoutView(onWorkoutCreated: {
                        navigateToNewWorkout = true
                    })
                }
                .sheet(isPresented: $showImbalanceInfo) {
                    if let advice = AnalyticsManager.getImbalanceRecommendation(recentWorkouts: recentWorkoutsForImbalance) {
                        ImbalanceDetailSheet(advice: advice)
                            .presentationDetents([.fraction(0.35)])
                            .presentationDragIndicator(.visible)
                    }
                }
        }
    }
    
    @ViewBuilder
    var content: some View {
        if recentWorkoutsForImbalance.isEmpty {
            emptyState
        } else {
            List {
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
                
                Section {
                    statsSection
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                Section {
                    searchAndFiltersSection
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                Section {
                    // ОПТИМИЗАЦИЯ: Передаем параметры фильтрации в динамический компонент
                    DynamicWorkoutListView(
                        searchText: searchText,
                        filter: selectedFilter,
                        sort: sortOption,
                        favoritesOnly: showFavoritesOnly,
                        avgDuration: $calculatedAvgDuration,
                        avgVolume: $calculatedAvgVolume
                    )
                }
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    title: LocalizedStringKey("Avg Duration"),
                    value: "\(calculatedAvgDuration)",
                    subtitle: LocalizedStringKey("min"),
                    icon: "stopwatch"
                )
                
                StatCard(
                    title: LocalizedStringKey("Avg Volume"),
                    value: "\(Int(unitsManager.convertFromKilograms(Double(calculatedAvgVolume))))",
                    subtitle: LocalizedStringKey(unitsManager.weightUnitString()),
                    icon: "scalemass"
                )
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            Picker(LocalizedStringKey("View Mode"), selection: $showFavoritesOnly) {
                Text(LocalizedStringKey("All Workouts")).tag(false)
                Text(LocalizedStringKey("Favorites")).tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            DebouncedSearchBar(text: $searchText)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Menu {
                    ForEach(FilterPeriod.allCases, id: \.self) { period in
                        Button(LocalizedStringKey(period.rawValue)) { selectedFilter = period }
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
                        Button(LocalizedStringKey(option.rawValue)) { sortOption = option }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(LocalizedStringKey(sortOption.rawValue))
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
}

// MARK: - Dynamic Workout List (OOM Protection)

struct DynamicWorkoutListView: View {
    @Environment(\.modelContext) private var context
    @Query private var workouts: [Workout]
    
    @Binding var calculatedAvgDuration: Int
    @Binding var calculatedAvgVolume: Int
    @Environment(WorkoutViewModel.self) var viewModel 
    init(searchText: String, filter: WorkoutView.FilterPeriod, sort: WorkoutView.SortOption, favoritesOnly: Bool, avgDuration: Binding<Int>, avgVolume: Binding<Int>) {
        self._calculatedAvgDuration = avgDuration
        self._calculatedAvgVolume = avgVolume
        
        let calendar = Calendar.current
        let now = Date()
        let cutoffDate: Date
        
        switch filter {
        case .all: cutoffDate = Date.distantPast
        case .week: cutoffDate = calendar.date(byAdding: .day, value: -7, to: now) ?? .distantPast
        case .month: cutoffDate = calendar.date(byAdding: .month, value: -1, to: now) ?? .distantPast
        case .threeMonths: cutoffDate = calendar.date(byAdding: .month, value: -3, to: now) ?? .distantPast
        case .year: cutoffDate = calendar.date(byAdding: .year, value: -1, to: now) ?? .distantPast
        }
        
        // Построение Предиката с поддержкой локального поиска
        let predicate: Predicate<Workout>
        if favoritesOnly {
            if searchText.isEmpty {
                predicate = #Predicate<Workout> { $0.date >= cutoffDate && $0.isFavorite }
            } else {
                predicate = #Predicate<Workout> { $0.date >= cutoffDate && $0.isFavorite && $0.title.localizedStandardContains(searchText) }
            }
        } else {
            if searchText.isEmpty {
                predicate = #Predicate<Workout> { $0.date >= cutoffDate }
            } else {
                predicate = #Predicate<Workout> { $0.date >= cutoffDate && $0.title.localizedStandardContains(searchText) }
            }
        }
        
        let sortDescriptors: [SortDescriptor<Workout>]
        switch sort {
        case .dateDescending: sortDescriptors = [SortDescriptor(\.date, order: .reverse)]
        case .dateAscending: sortDescriptors = [SortDescriptor(\.date, order: .forward)]
        case .durationDescending: sortDescriptors = [SortDescriptor(\.durationSeconds, order: .reverse)]
        case .durationAscending: sortDescriptors = [SortDescriptor(\.durationSeconds, order: .forward)]
        case .effortDescending: sortDescriptors = [SortDescriptor(\.effortPercentage, order: .reverse)]
        case .effortAscending: sortDescriptors = [SortDescriptor(\.effortPercentage, order: .forward)]
        }
        
        _workouts = Query(filter: predicate, sort: sortDescriptors)
    }
    
    var body: some View {
        if workouts.isEmpty {
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
            ForEach(workouts) { workout in
                ZStack {
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) { EmptyView() }.opacity(0)
                    WorkoutRow(workout: workout)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete { indexSet in
                withAnimation {
                    for index in indexSet {
                        let workoutToDelete = workouts[index]
                        viewModel.deleteWorkout(workoutToDelete) // ЧИСТО! Логика во ViewModel
                    }
                }
            }
            .onChange(of: workouts, initial: true) { _, newWorkouts in
                calculateStatsAsync(workouts: newWorkouts)
            }
        }
    }
    
    private func calculateStatsAsync(workouts: [Workout]) {
        let totalWorkouts = workouts.count
        guard totalWorkouts > 0 else {
            calculatedAvgDuration = 0
            calculatedAvgVolume = 0
            return
        }
        
        // Move heavy aggregation to a background thread
        Task.detached(priority: .userInitiated) {
            var totalDur = 0
            var totalVol = 0.0
            
            // Iterate safely in the background
            for workout in workouts {
                totalDur += (workout.durationSeconds / 60)
                for exercise in workout.exercises {
                    totalVol += exercise.exerciseVolume
                }
            }
            
            let avgDur = totalDur / totalWorkouts
            let avgVol = Int(totalVol / Double(totalWorkouts))
            
            // Return to MainActor to update UI bindings
            await MainActor.run {
                self.calculatedAvgDuration = avgDur
                self.calculatedAvgVolume = avgVol
            }
        }
    }
}

// MARK: - Debounced Search Bar

struct DebouncedSearchBar: View {
    @Binding var text: String
    @State private var localText: String
    @State private var debounceTask: Task<Void, Never>? = nil
    
    init(text: Binding<String>) {
        self._text = text
        self._localText = State(initialValue: text.wrappedValue)
    }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(LocalizedStringKey("Search workouts..."), text: $localText)
                .textFieldStyle(.plain)
                .onChange(of: localText) { oldValue, newValue in
                    debounceTask?.cancel()
                    debounceTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if !Task.isCancelled { text = newValue }
                    }
                }
                .onChange(of: text) { oldValue, newValue in
                    if localText != newValue { localText = newValue }
                }
            if !localText.isEmpty {
                Button(action: { localText = ""; text = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Helper Views

// --- ВСПЛЫВАЮЩЕЕ ОКНО СОВЕТА ---
struct ImbalanceDetailSheet: View {
    let advice: (title: String, message: String)
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
                .padding(.top, 20)
            
            VStack(spacing: 8) {
                Text(LocalizedStringKey(advice.title))
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                
                Text(LocalizedStringKey(advice.message))
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

// --- ИНДИКАТОР ТЕКУЩЕЙ ТРЕНИРОВКИ ---
struct ActiveWorkoutIndicator: View {
    @State private var isBlinking = false
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 8, height: 8)
            .opacity(isBlinking ? 0.2 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBlinking)
            .onAppear {
                isBlinking = true
            }
            .onDisappear {
                isBlinking = false
            }
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
    
    var safeIcon: String { UIImage(systemName: workout.icon) != nil ? workout.icon : "figure.run" }
    
    var body: some View {
        HStack {
            Image(systemName: safeIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(workout.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if workout.isActive { ActiveWorkoutIndicator() }
                }
                Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if workout.isActive {
                    Text(LocalizedStringKey("In Progress"))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.blue)
                } else {
                    Text(LocalizedStringKey("\(workout.durationSeconds / 60) min"))
                        .font(.subheadline)
                        .bold()
                }
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
        .compositingGroup()
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// --- КАРТОЧКА СТАТИСТИКИ ---
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
        .compositingGroup()
    }
}

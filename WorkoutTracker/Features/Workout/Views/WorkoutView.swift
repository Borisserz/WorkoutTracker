internal import SwiftUI
import SwiftData
import UIKit

// MARK: - Main View

struct WorkoutView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.modelContext) private var context
    @Environment(WorkoutService.self) var workoutService
    @Environment(UnitsManager.self) var unitsManager
    @Environment(DashboardViewModel.self) var dashboardViewModel
    
    @State private var showImbalanceInfo = false
    @State private var showAddWorkout = false
    @State private var navigateToNewWorkout = false
    
    @State private var searchDebouncer = SearchDebouncer()
    
    @State private var selectedFilter: FilterPeriod = .all
    @State private var sortOption: SortOption = .dateDescending
    @State private var showFavoritesOnly = false
    
    @State private var listViewModel = WorkoutListViewModel()
    
    @State private var imbalanceAdvice: (title: String, message: String)? = nil
    @State private var recentWorkoutForNavigation: Workout? = nil
    
    enum FilterPeriod: String, CaseIterable {
            case all = "All Time"
            case week = "Last Week"
            case month = "Last Month"
            case threeMonths = "Last 3 Months"
            case year = "Last Year"
            
            // ✅ ДОБАВЛЯЕМ ЭТО СВОЙСТВО
            var localizedName: LocalizedStringKey {
                switch self {
                case .all: return "All Time"
                case .week: return "Last Week"
                case .month: return "Last Month"
                case .threeMonths: return "Last 3 Months"
                case .year: return "Last Year"
                }
            }
        }
        
        enum SortOption: String, CaseIterable {
            case dateDescending = "Newest First"
            case dateAscending = "Oldest First"
            case durationDescending = "Longest First"
            case durationAscending = "Shortest First"
            case effortDescending = "Highest Effort"
            case effortAscending = "Lowest Effort"
            
            // ✅ ДОБАВЛЯЕМ ЭТО СВОЙСТВО
            var localizedName: LocalizedStringKey {
                switch self {
                case .dateDescending: return "Newest First"
                case .dateAscending: return "Oldest First"
                case .durationDescending: return "Longest First"
                case .durationAscending: return "Shortest First"
                case .effortDescending: return "Highest Effort"
                case .effortAscending: return "Lowest Effort"
                }
            }
        }
    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("History"))
                .navigationDestination(isPresented: $navigateToNewWorkout) {
                    if let workout = recentWorkoutForNavigation {
                        WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    
                    if imbalanceAdvice != nil {
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
                        // ✅ FIX: Безопасный поиск созданной тренировки на MainActor
                        Task { @MainActor in
                            var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                            descriptor.fetchLimit = 1
                            if let newWorkout = try? context.fetch(descriptor).first {
                                self.recentWorkoutForNavigation = newWorkout
                                self.navigateToNewWorkout = true
                            }
                        }
                    })
                }
                .sheet(isPresented: $showImbalanceInfo) {
                    if let advice = imbalanceAdvice {
                        ImbalanceDetailSheet(advice: advice)
                            .presentationDetents([.fraction(0.35)])
                            .presentationDragIndicator(.visible)
                    }
                }
        }
        .onAppear {
            loadImbalanceData()
        }
        .onChange(of: dashboardViewModel.dashboardTotalExercises) { _, _ in
            loadImbalanceData()
        }
    }
    
    @ViewBuilder
    var content: some View {
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
                DynamicWorkoutListView(
                    searchText: searchDebouncer.debouncedText,
                    filter: selectedFilter,
                    sort: sortOption,
                    favoritesOnly: showFavoritesOnly,
                    listViewModel: listViewModel,
                    onFirstWorkoutLoaded: { workout in
                        self.recentWorkoutForNavigation = workout
                    }
                )
            }
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var statsSection: some View {
            // Вычисляем тонны
            let tons = Double(listViewModel.calculatedAvgVolume) / 1000.0
            let formattedTons = LocalizationHelper.shared.formatTwoDecimals(tons)
            
            return VStack(spacing: 12) {
                HStack(spacing: 12) {
                    StatCard(
                        title: LocalizedStringKey("Avg Duration"),
                        value: "\(listViewModel.calculatedAvgDuration)",
                        subtitle: LocalizedStringKey("min"),
                        icon: "stopwatch"
                    )
                    
                    StatCard(
                        title: LocalizedStringKey("Avg Volume"),
                        value: formattedTons,
                        subtitle: LocalizedStringKey("tons"), // Жестко задаем тонны
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
            
            DebouncedSearchBar(debouncer: searchDebouncer)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Menu {
                                    ForEach(FilterPeriod.allCases, id: \.self) { period in
                                        Button(period.localizedName) { selectedFilter = period } // ✅ Замена
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "calendar")
                                        Text(selectedFilter.localizedName) // ✅ Замена
                                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                Menu {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Button(option.localizedName) { sortOption = option } // ✅ Замена
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.up.arrow.down")
                                        Text(sortOption.localizedName) // ✅ Замена
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
    
    private func loadImbalanceData() {
        if let balanceRec = dashboardViewModel.recommendations.first(where: { $0.type == .balance }) {
            imbalanceAdvice = (title: balanceRec.title, message: balanceRec.message)
        } else {
            imbalanceAdvice = nil
        }
    }
}

// MARK: - Dynamic Workout List (OOM Protection)

struct DynamicWorkoutListView: View {
    @Environment(\.modelContext) private var context
    @Query private var workouts: [Workout]
    @Environment(DashboardViewModel.self) var dashboardViewModel
    @Environment(WorkoutService.self) var workoutService
    @Environment(DIContainer.self) private var di
    var listViewModel: WorkoutListViewModel
    var onFirstWorkoutLoaded: ((Workout) -> Void)?
    
    init(searchText: String, filter: WorkoutView.FilterPeriod, sort: WorkoutView.SortOption, favoritesOnly: Bool, listViewModel: WorkoutListViewModel, onFirstWorkoutLoaded: ((Workout) -> Void)? = nil) {
        self.listViewModel = listViewModel
        self.onFirstWorkoutLoaded = onFirstWorkoutLoaded
        
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
            .padding(.vertical, 60)
            .frame(maxWidth: .infinity)
            .onAppear {
                onFirstWorkoutLoaded?(Workout(title: "", date: Date()))
            }
        } else {
            ForEach(workouts) { workout in
                ZStack {
                    NavigationLink(destination: WorkoutDetailView(workout: workout, viewModel: di.makeWorkoutDetailViewModel())) { EmptyView() }.opacity(0)
                    WorkoutRow(workout: workout)
                }
                .padding(.vertical, 6)
            }
            .onDelete { indexSet in
                withAnimation {
                    for index in indexSet {
                        let workoutToDelete = workouts[index]
                        Task { await workoutService.deleteWorkout(workoutToDelete) }
                    }
                }
            }
            .onChange(of: workouts, initial: true) { _, newWorkouts in
                listViewModel.calculateStatsAsync(workouts: newWorkouts)
                if let first = newWorkouts.first {
                    onFirstWorkoutLoaded?(first)
                }
            }
        }
    }
}

// MARK: - Premium Workout Row

struct WorkoutRow: View {
    let workout: Workout
    @Environment(UnitsManager.self) var unitsManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isBlinking = false
    
    var safeIcon: String { UIImage(systemName: workout.icon) != nil ? workout.icon : "figure.run" }
    
    var body: some View {
        VStack(spacing: 12) {
            // Верхняя часть: Иконка, Название, Дата, LIVE-бейдж
            HStack(alignment: .top, spacing: 14) {
                // Иконка
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue.opacity(0.15), .cyan.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: safeIcon)
                        .font(.title2)
                        .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(workout.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if workout.isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .opacity(isBlinking ? 0.3 : 1.0)
                                Text("LIVE")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider().opacity(0.5)
            
            // Нижняя часть: Мини-грид статистики
            HStack(spacing: 20) {
                miniStat(icon: "stopwatch.fill", value: workout.isActive ? "In Progress" : "\(workout.durationSeconds / 60)m")
                miniStat(icon: "list.bullet", value: "\(workout.exercises.count) exs")
                miniStat(icon: "scalemass.fill", value: "\(Int(unitsManager.convertFromKilograms(workout.totalStrengthVolume))) \(unitsManager.weightUnitString())")
                
                Spacer()
                
                // Effort Capsule
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(workout.effortPercentage)%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(effortGradient(workout.effortPercentage).opacity(0.15))
                .foregroundColor(effortColor(workout.effortPercentage))
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 8, x: 0, y: 4)
        // Пульсирующая обводка для активной тренировки
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(workout.isActive ? Color.blue.opacity(isBlinking ? 0.8 : 0.2) : Color.clear, lineWidth: workout.isActive ? 2 : 0)
        )
        .onAppear {
            if workout.isActive {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            }
        }
    }
    
    private func miniStat(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    private func effortColor(_ percentage: Int) -> Color {
        if percentage > 80 { return .red }
        if percentage > 50 { return .orange }
        return .green
    }
    
    private func effortGradient(_ percentage: Int) -> LinearGradient {
        if percentage > 80 { return LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing) }
        if percentage > 50 { return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing) }
        return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Clean Debounced Search Bar

struct DebouncedSearchBar: View {
    @Bindable var debouncer: SearchDebouncer
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            
            TextField(LocalizedStringKey("Search workouts..."), text: $debouncer.inputText)
                .textFieldStyle(.plain)
            
            if !debouncer.inputText.isEmpty {
                Button(action: { debouncer.inputText = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Helper Views

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

struct ActiveWorkoutIndicator: View {
    @State private var isBlinking = false
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 8, height: 8)
            .opacity(isBlinking ? 0.2 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBlinking)
            .onAppear { isBlinking = true }
            .onDisappear { isBlinking = false }
    }
}


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
